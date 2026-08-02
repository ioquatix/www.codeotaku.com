# The Case of the Vanishing Fiber: A Ruby Mystery

*Being an account of a Fiber which disappeared while Ruby was still returning to it, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Crash After the Error

The case began with an ordinary network failure. A server ended a chunked HTTP response before its final chunk, <code class="language-ruby">Async::HTTP</code> raised <code class="language-ruby">EOFError</code>, and its tasks began to unwind.

Then Ruby itself crashed.

The [original report](https://bugs.ruby-lang.org/issues/22196) described an intermittent failure on Ruby 3.4.10. Its C backtrace ended in <code class="language-c">fiber_pool_stack_release</code>, far below the HTTP code which appeared to provoke it:

```text
fiber_pool_stack_release
fiber_stack_release
fiber_switch
rb_fiber_start
```

“The failed response is merely the witness,” Holmes said. “The crime occurred while Ruby was changing Fibers.”

That distinction mattered. An incomplete response should terminate a task with an exception. It should not corrupt the virtual machine which delivers it.

## Chapter II: Making Chance Repeat Itself

The first reproduction used <code class="language-ruby">Async::HTTP</code>, many truncated responses, and enough scheduling pressure to make the crash appear occasionally. It established that the problem was real, but it left too many suspects: sockets, HTTP parsing, task cancellation, the Fiber scheduler, and garbage collection.

AddressSanitizer changed the character of the investigation. Instead of observing a later crash in stack cleanup, it stopped at the first invalid access:

```text
ERROR: AddressSanitizer: heap-use-after-free
READ of size 1
    #0 fiber_switch .../cont.c
freed by thread here:
    cont_free .../cont.c
    fiber_free .../cont.c
```

The clue was precise. <code class="language-c">fiber_switch</code> was reading a Fiber after the garbage collector had freed it.

We reduced the network workload until it contained little more than a tiny TCP server sending truncated chunked responses and a collection of failed asynchronous tasks. But Holmes insisted that the final explanation should not depend on HTTP at all.

“A protocol can reveal a scheduling defect,” he said, “but it cannot define one.”

## Chapter III: A Fiber Is Both an Object and an Execution Context

At Ruby level, a Fiber is an object. As long as Ruby code can reach that object, the garbage collector keeps it alive. Inside CRuby, the same Fiber is represented by an <code class="language-c">rb_fiber_t</code> structure containing its execution state.

That usually leads to an obvious rule: native code may use the internal pointer while the Ruby object is live. Fiber switching makes the rule less obvious because a C function can suspend in the middle of its execution.

The relevant shape in <code class="language-c">fiber_switch</code> was:

```c
fiber_store(fiber, th);

if (FIBER_TERMINATED_P(fiber)) {
    fiber_stack_release(fiber);
}
```

<code class="language-c">fiber_store</code> does not behave like an ordinary call which returns immediately. It switches execution to another Fiber. Arbitrary Ruby code may run, references may be cleared, and garbage collection may occur before the suspended C frame resumes.

The local variable <code class="language-c">fiber</code> was only a raw C pointer. The garbage collector could not see it as a reference keeping the Ruby Fiber object alive.

## Chapter IV: The Smallest Crime Scene

Once we understood the lifetime boundary, the HTTP reproducer gave way to a pure Ruby test involving nested <code class="language-ruby">Fiber#resume</code>, <code class="language-ruby">Fiber.yield</code>, and an explicit collection.

Its essential sequence was:

1. A parent Fiber created two children and yielded to the root Fiber.
2. The first child resumed the parent.
3. The parent discarded its last Ruby reference to that child, then yielded back to it.
4. While the parent's native <code class="language-c">fiber_switch</code> frame remained suspended, the first child terminated.
5. The second child invoked <code class="language-ruby">GC.start</code>, allowing the first child to be collected.
6. Execution returned to the suspended C frame, which read its now-stale <code class="language-c">rb_fiber_t *</code>.

Nothing in this sequence required networking, threads, or Async. Those components had only made the unusual ordering possible often enough to notice.

“We have removed every footprint except the murderer's,” I said.

“And discovered that the footprint belongs to time itself,” Holmes replied. “The pointer was valid when the function began. It was not valid when the function continued.”

## Chapter V: The Earlier Change

The crash appeared in Ruby 3.4.10 after the fix for [Bug #21955](https://bugs.ruby-lang.org/issues/21955) broadened the handling of Fibers which terminate during a switch. Previously, one post-switch check was limited to <code class="language-ruby">Fiber#resume</code>. The change correctly applied it to <code class="language-ruby">Fiber.yield</code> and <code class="language-ruby">Fiber#transfer</code> as well.

That did not make the broader behavior wrong. It exposed a pre-existing lifetime assumption: once more switch paths used <code class="language-c">fiber</code> after <code class="language-c">fiber_store</code>, every one of those paths needed the target object to survive the suspension.

Reinstating the old condition made the observed crash disappear, but it would also have discarded the intended semantic fix. The better question was not “how do we avoid this read?” but “why is the object allowed to die before the read is finished?”

## Chapter VI: Guarding What C Still Needs

The [final Ruby fix](https://github.com/ruby/ruby/pull/17957) was deliberately small:

```c
VALUE fiber_value = fiber->cont.self;

fiber_store(fiber, th);

/* final uses of fiber */
RB_GC_GUARD(fiber_value);
```

<code class="language-c">RB_GC_GUARD</code> tells the compiler and Ruby's garbage collector that the Ruby object stored in <code class="language-c">fiber_value</code> must remain live through that point. The native pointer may still span a Fiber switch, but its owner can no longer be collected before the last pointer access.

The regression test preserved the nested resume/yield ordering and forced collection while the C frame was suspended. A stock Ruby 3.4.10 ASan build reproduced the use-after-free; the guarded build completed without it. The fix was also [backported to Ruby 3.4](https://bugs.ruby-lang.org/issues/22196#note-5).

## Epilogue: Liveness Across Suspension

The lesson is broader than Fibers. Native code often reasons about object lifetime from the lexical shape of a function: obtain a pointer, use it, return. Suspension breaks that intuition. Between two adjacent lines of C, another execution context can run Ruby, remove references, and invoke the garbage collector.

Any raw pointer used after such a boundary needs an owner whose lifetime is explicit. The source code may place the two uses together; time does not.

Holmes closed the debugger.

“The Fiber did not vanish while we were looking away, Watson. It vanished while our own frame was asleep.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
