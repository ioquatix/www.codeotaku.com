# The Case of the Vanishing Fiber: A Ruby Mystery

*Being an account of a Fiber which disappeared while Ruby was still returning to it, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Crash After the Error

The telegram arrived at Baker Street with two failures recorded upon it. The first was unremarkable:

```text
EOFError: unexpected end of chunked response
```

The second was considerably less so:

```text
fiber_pool_stack_release
fiber_stack_release
fiber_switch
rb_fiber_start
```

“A server truncated an HTTP response,” I said. “<code class="language-ruby">Async::HTTP</code> raised <code class="language-ruby">EOFError</code>, its task unwound, and Ruby crashed. Shall we begin with the HTTP parser?”

Holmes placed the two traces side by side. “What should happen when a response ends early, Watson?”

“The task should fail with <code class="language-ruby">EOFError</code>.”

“Then the first failure is expected. The mystery is why reporting it disturbed Ruby's Fiber machinery.”

The [original report](https://bugs.ruby-lang.org/issues/22196) described an intermittent crash on Ruby 3.4.10. A busy asynchronous workload made it visible, but the C backtrace pointed beneath sockets and HTTP. Our first task was to separate the circumstance which revealed the defect from the mechanism which caused it.

## Chapter II: Making Chance Repeat Itself

The reproduction sent many deliberately truncated responses through <code class="language-ruby">Async::HTTP</code>. Sometimes every task failed cleanly. Sometimes the Ruby process crashed.

“A timing problem,” I suggested. “Perhaps two tasks are modifying the same Fiber.”

“Perhaps,” said Holmes. “But intermittency tells us only that the necessary ordering is uncommon. We need a witness who stops the program at the first offence, not at the later commotion.”

We rebuilt Ruby with AddressSanitizer. The uncertain crash became a precise accusation:

```text
ERROR: AddressSanitizer: heap-use-after-free
READ of size 1
    #0 fiber_switch .../cont.c
freed by thread here:
    cont_free .../cont.c
    fiber_free .../cont.c
```

“So <code class="language-c">fiber_switch</code> released the Fiber and then read it?” I asked.

Holmes shook his head. “Look more closely. The garbage collector freed it. <code class="language-c">fiber_switch</code> merely continued to believe it was alive.”

That distinction gave us a stronger question: how could Ruby collect a Fiber while native code was still using its internal pointer?

## Chapter III: The Two Identities of a Fiber

Holmes drew two names for the same suspect on the blackboard:

```text
Ruby object:     Fiber
native state:    rb_fiber_t *
```

“At Ruby level,” he said, “the garbage collector keeps an object alive while Ruby can reach it. Inside CRuby, native code often works with the object's underlying structure.”

“And the structure belongs to the object,” I replied. “Therefore the pointer is valid while the object is alive.”

“Correct. Now reverse the statement.”

I hesitated. “If C still holds the pointer, the object must be alive?”

“That is the assumption we must test. Can Ruby's garbage collector see an ordinary C local containing <code class="language-c">rb_fiber_t *</code> as a reference to the owning Ruby object?”

It could not. A raw native pointer is useful to C, but it is not automatically a Ruby-level reference. If all visible references to the Fiber disappeared, the garbage collector could reclaim the object and its native state even though a C stack frame still remembered the address.

“Then every use of such a pointer is dangerous,” I said.

“Only if garbage collection can run between obtaining it and using it. Let us find that interval.”

## Chapter IV: The Function Which Paused Mid-Sentence

The relevant code appeared almost too ordinary:

```c
fiber_store(fiber, th);

if (FIBER_TERMINATED_P(fiber)) {
    fiber_stack_release(fiber);
}
```

“The pointer is used immediately after <code class="language-c">fiber_store</code> returns,” I said. “Where could collection intervene?”

“You are reading it as an ordinary function call,” Holmes replied. “What does <code class="language-c">fiber_store</code> actually do?”

“It switches to another Fiber.”

“And when does this C frame continue?”

The answer altered the apparent shape of the code. <code class="language-c">fiber_store</code> could suspend its caller. Before it returned, another Fiber might execute arbitrary Ruby code, remove references, and invoke the garbage collector. Two adjacent lines of C could be separated by an entire episode of Ruby execution.

“The function has paused midway through a sentence,” I said, “and resumes using a noun which may no longer exist.”

“Precisely. Source proximity is not lifetime continuity.”

## Chapter V: Reconstructing the Disappearance

We no longer needed the whole HTTP workload. Holmes proposed that we recreate only the ordering which made the pointer stale.

“We need one Fiber whose C frame is suspended,” he said, “another which removes the last Ruby reference to its target, and a third which forces collection before the first frame resumes.”

The reduced pure-Ruby test used nested <code class="language-ruby">Fiber#resume</code>, <code class="language-ruby">Fiber.yield</code>, and <code class="language-ruby">GC.start</code>. Its sequence was:

1. A parent Fiber created two children and yielded to the root Fiber.
2. The first child resumed the parent.
3. The parent discarded its last Ruby reference to that child, then yielded back to it.
4. The parent's native <code class="language-c">fiber_switch</code> frame remained suspended while the first child terminated.
5. The second child invoked <code class="language-ruby">GC.start</code>, allowing the first child to be collected.
6. Execution returned to the suspended C frame, which read its stale <code class="language-c">rb_fiber_t *</code>.

“No HTTP,” I observed.

“Nor sockets, nor an event loop,” said Holmes.

“Then Async did not cause the defect. Its task cleanup merely arranged these Fiber transitions often enough to expose it.”

Holmes nodded. The network reproduction remained valuable because it showed practical impact. The pure-Ruby reproduction was valuable for a different reason: it proved which Ruby semantics were sufficient to produce the invalid lifetime.

## Chapter VI: The Suspicious Earlier Change

The crash appeared in Ruby 3.4.10 after the fix for [Bug #21955](https://bugs.ruby-lang.org/issues/21955). That change broadened the handling of Fibers which terminate during a switch. A post-switch check previously limited to <code class="language-ruby">Fiber#resume</code> now applied correctly to <code class="language-ruby">Fiber.yield</code> and <code class="language-ruby">Fiber#transfer</code> as well.

“There is our regression,” I said. “Restore the old condition and the invalid read disappears.”

“Does the old condition make the pointer live?” Holmes asked.

“No. It avoids reading it on those paths.”

“And why was the condition broadened?”

“Because terminated targets require handling on those paths too.”

The apparent remedy would have hidden the lifetime defect by abandoning the intended semantic fix. The earlier change had made a stale-pointer read observable, but the unsafe assumption was more fundamental: any path using <code class="language-c">fiber</code> after a suspending switch needed to keep its owner alive.

“A recent change may reveal the room in which the crime occurs,” Holmes said. “That does not make the room the culprit.”

## Chapter VII: Guarding What C Still Needs

The [final Ruby fix](https://github.com/ruby/ruby/pull/17957) was small enough to fit beneath Holmes's earlier diagram:

```c
VALUE fiber_value = fiber->cont.self;

fiber_store(fiber, th);

/* final uses of fiber */
RB_GC_GUARD(fiber_value);
```

“We copy the owning Ruby object into <code class="language-c">fiber_value</code>,” I said. “But why place <code class="language-c">RB_GC_GUARD</code> after the switch?”

“Because the guard marks the end of the lifetime we require. It tells the compiler and garbage collector that the Ruby value must remain live until every native-pointer use above it is complete.”

The pointer itself did not become visible to the garbage collector. Instead, the code retained the Ruby object which owned it. That preserved both the object and its <code class="language-c">rb_fiber_t</code> across the suspended interval.

The regression test preserved the nested resume/yield ordering and forced collection while the C frame was paused. A stock Ruby 3.4.10 ASan build reproduced the use-after-free; the guarded build completed without it. The fix was also [backported to Ruby 3.4](https://bugs.ruby-lang.org/issues/22196#note-5).

## Epilogue: Liveness Across Suspension

“I had treated the C function as one uninterrupted act,” I said as Holmes closed the debugger. “The code encouraged me to do so: acquire a pointer, call a function, inspect the pointer.”

“And yet that call yielded control to Ruby,” he replied. “Whenever native code crosses a boundary which can execute arbitrary Ruby, its assumptions about object lifetime must survive the same journey.”

The lesson extends beyond Fibers. A callback, scheduler hand-off, or other suspension point can place substantial execution between adjacent native instructions. Any raw pointer used afterward needs an owner whose lifetime is explicit.

“Then the Fiber did not vanish while we were looking away,” I concluded. “It vanished while our own frame was asleep.”

“Exactly, Watson.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
