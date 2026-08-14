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

The [original report](https://bugs.ruby-lang.org/issues/22196) described an intermittent crash on Ruby 3.4.10. A busy asynchronous workload made it visible, but the C backtrace pointed beneath sockets and HTTP.

“Then we must separate the circumstance which revealed the defect from the mechanism which caused it,” Holmes said.

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

“Then how could Ruby collect a Fiber while native code was still using its internal pointer?” I asked.

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

“It cannot,” Holmes said. “A raw native pointer is useful to C, but it is not automatically a Ruby-level reference. If all visible references to the Fiber disappear, the garbage collector may reclaim the object and its native state even though a C stack frame still remembers the address.”

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

“Not until execution returns to it,” I said. “Before that happens, another Fiber may execute arbitrary Ruby code, remove references, and invoke the garbage collector.”

“Then two adjacent lines of C can be separated by an entire episode of Ruby execution,” Holmes replied.

“The function has paused midway through a sentence,” I said, “and resumes using a noun which may no longer exist.”

“Precisely. Source proximity is not lifetime continuity.”

## Chapter V: Reconstructing the Disappearance

We no longer needed the whole HTTP workload. Holmes proposed that we recreate only the ordering which made the pointer stale.

“We need a <code class="language-c">fiber_switch</code> frame suspended while it still holds its target as a raw pointer,” he said. “Then Ruby code must remove the last reference to that target and force collection before the frame resumes.”

The reduced pure-Ruby test used nested <code class="language-ruby">Fiber#resume</code>, <code class="language-ruby">Fiber.yield</code>, and <code class="language-ruby">GC.start</code>. Its sequence was:

1. A parent Fiber created two children and yielded to the root Fiber.
2. The first child resumed the parent.
3. The parent discarded its last Ruby reference to that child, then yielded back to it.
4. The parent's native <code class="language-c">fiber_switch</code> frame remained suspended while the first child terminated.
5. The second child invoked <code class="language-ruby">GC.start</code>, allowing the first child to be collected.
6. Execution returned to the suspended C frame, which read its stale <code class="language-c">rb_fiber_t *</code>.

“The first child is the target Fiber still held by the parent's suspended <code class="language-c">fiber_switch</code> call,” I said. “Once the parent discards its Ruby reference, the raw pointer in that C frame is all that remains.”

“And the garbage collector does not treat that raw pointer as a reference,” Holmes replied.

“No HTTP,” I observed.

“Nor sockets, nor an event loop,” said Holmes.

“Then Async did not cause the defect. Its task cleanup merely arranged these Fiber transitions often enough to expose it.”

“The network reproduction shows the practical impact,” I said. “The pure-Ruby reproduction proves which Ruby semantics are sufficient to produce the invalid lifetime.”

Holmes nodded. “The witness and the reconstruction serve different purposes.”

## Chapter VI: The Suspicious Earlier Change

The crash appeared in Ruby 3.4.10 after the fix for [Bug #21955](https://bugs.ruby-lang.org/issues/21955). That change broadened the handling of Fibers which terminate during a switch. A post-switch check previously limited to <code class="language-ruby">Fiber#resume</code> now applied correctly to <code class="language-ruby">Fiber.yield</code> and <code class="language-ruby">Fiber#transfer</code> as well.

“There is our regression,” I said. “Restore the old condition and the invalid read disappears.”

“Does the old condition make the pointer live?” Holmes asked.

“No. It avoids reading it on those paths.”

“And why was the condition broadened?”

“Because terminated targets require handling on those paths too.”

“Then restoring the old condition would only hide the lifetime defect,” I said. “It would also abandon the intended handling of terminated targets.”

“Exactly,” Holmes replied. “The earlier change makes the stale-pointer read observable, but the underlying rule is more fundamental: any path using <code class="language-c">fiber</code> after a suspending switch must keep its owner alive.”

## Chapter VII: Guarding What C Still Needs

The [final Ruby fix](https://github.com/ruby/ruby/pull/17957) was small enough to fit beneath Holmes's earlier diagram:

```c
VALUE fiber_value = fiber->cont.self;

fiber_store(fiber, th);

/* final uses of fiber */
RB_GC_GUARD(fiber_value);
```

“We copy the owning Ruby object into <code class="language-c">fiber_value</code>,” I said. “But why place <code class="language-c">RB_GC_GUARD</code> after the switch?”

“Because the guard marks the end of the lifetime we require,” Holmes replied. “It prevents the compiler from treating <code class="language-c">fiber_value</code> as dead before that point, so Ruby's garbage collector can continue to see the owning Fiber object as live.”

“The raw pointer itself does not become a garbage collector reference,” I said. “We keep its owner alive instead.”

“And preserving the owner preserves its <code class="language-c">rb_fiber_t</code> across the suspended interval,” Holmes replied.

The regression test preserved the nested resume/yield ordering and forced collection while the C frame was paused. A stock Ruby 3.4.10 ASan build reproduced the use-after-free; the guarded build completed without it. The fix was also [backported to Ruby 3.4](https://bugs.ruby-lang.org/issues/22196#note-5).

## Epilogue: Liveness Across Suspension

“I had treated the C function as one uninterrupted act,” I said as Holmes closed the debugger. “The code encouraged me to do so: acquire a pointer, call a function, inspect the pointer.”

“And yet that call yielded control to Ruby,” he replied. “Whenever native code crosses a boundary which can execute arbitrary Ruby, its assumptions about object lifetime must survive the same journey.”

“Then the lesson extends beyond Fibers,” I said. “A callback or scheduler hand-off can also place substantial execution between adjacent native instructions.”

“Indeed. Any raw pointer used after such a boundary needs an owner whose lifetime is explicit.”

“Then the Fiber did not vanish while we were looking away,” I concluded. “It vanished while our own frame was asleep.”

“Exactly, Watson.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
