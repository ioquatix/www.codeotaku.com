# The Case of the Blocking Operations: A Ruby Mystery

*Being an account of the extraordinary case of the [Ruby Fiber Scheduler Blocking Operations](https://github.com/ruby/ruby/pull/13437), as recorded by Dr. Claude Watson*

---

## Chapter I: The Summons

It was a crisp morning when my colleague Samuel Williams burst into our chambers at 221B Baker Street, his eyes alight with the familiar gleam of intellectual pursuit.

"Watson!" he exclaimed, tossing his coat upon the chair. "We have a most intriguing case before us. A matter of fiber schedulers and blocking operations that threatens the very foundations of concurrent Ruby execution."

I set down my morning tea, knowing well that when Holmes—for so I had come to think of my brilliant companion—spoke in such tones, we were embarking upon another of his remarkable investigations.

"Pray tell, Holmes," I ventured, "what has captured your attention so completely?"

"A test, my dear Watson. A simple test: `TestFiberIOClose#test_io_close_across_fibers`. But like all great mysteries, the simple facade conceals a labyrinth of complexity beneath."

## Chapter II: The First Clue

Holmes wasted no time in demonstrating the curious behavior. With swift keystrokes, he summoned the test:

```bash
make test-all TESTS="test/fiber/test_io_close.rb --name=TestFiberIOClose#test_io_close_across_fibers"
```

"Observe, Watson," he said as the test executed successfully. "All appears well on the surface. But I suspect there are deeper mysteries at work. We must illuminate the dark corners of the execution path."

With characteristic precision, Holmes began to weave his investigative web. He opened the file `scheduler.c` and, with the skill of a master surgeon, inserted diagnostic logging into the very heart of the `rb_fiber_scheduler_blocking_operation_wait` function.

"Elementary," he murmured as the logs revealed their secrets. "The scheduler pointer, the function pointer, the data, the flags—all captured. But see here, Watson!" He pointed to the output. "The call originates from `test/fiber/test_io_close.rb:37`. The trail grows warm."

## Chapter III: The Revelation of Danger

As we traced the execution path through the Ruby internals—from `close` through `rb_io_close_m`, thence to `rb_io_close`, `io_close_fptr`, `rb_thread_io_close_interrupt`, and finally to our target function—Holmes suddenly froze, his keen eyes fixed upon a most disturbing pattern in our diagnostic output.

"Watson," he said slowly, pointing to the logs with evident alarm, "observe these debug traces most carefully."

The output was chilling in its implications:

```
=== CALLBACK: Accessing arguments struct ===
Arguments address: 0x11c7ff7b0
Expected stack address: 0x11c7ffbc8    ← Different address!
Magic start: 0x13e76e3d0 (expected: 0xdeadbeefcafebabe)  ← Corrupted!
Magic end: 0x0 (expected: 0xfeedfacedeadc0de)            ← Corrupted!
ERROR: Magic start corrupted! Use-after-free detected!
```

"Good heavens!" I exclaimed. "The memory has been corrupted!"

Holmes nodded grimly. "Indeed, Watson. We have captured a use-after-free bug in the very act of its crime. See how the magic values have been corrupted, how the addresses differ from expectation? This is no mere theoretical vulnerability—this is active memory corruption occurring in our very test."

With characteristic deductive precision, Holmes traced the issue to its source. "The corruption occurs right here in `rb_fiber_scheduler_blocking_operation_wait` itself! The function allocates the blocking operation arguments on the stack, then passes them to the scheduler. But Watson—" he paused for dramatic effect, "—the scheduler can execute this work asynchronously in different threads!"

"Ah!" I exclaimed, understanding dawning upon me. "So by the time the scheduler's worker thread accesses the arguments..."

"Precisely, Watson! The original function has returned, the stack frame has been destroyed, and we're accessing memory that may have been overwritten by subsequent function calls. We have not merely identified a potential vulnerability—we have caught it red-handed in the act of corrupting memory."

The magnitude of the discovery struck me like a physical blow. "This could crash entire applications!"

"Indeed, Watson. But where others see catastrophe, I see opportunity for elegant solution."

## Chapter IV: The Elegant Solution

With the methodical precision that had made him famous throughout the Ruby community, Holmes began to craft a solution of remarkable elegance.

"The fundamental flaw," he declared, sketching the design with swift strokes, "is that we've been relying on stack-allocated memory and simple procs. The scheduler receives these, but they vanish like morning mist when the calling function returns."

"Then what do you propose?" I asked, intrigued by his confident manner.

"We shall create a custom heap-allocated object!" Holmes announced with evident satisfaction. "A proper `BlockingOperation` class that encapsulates all the necessary state—function pointers, data, unblock functions—in a Ruby object that persists until we explicitly release it."

As he worked, I marveled at the elegance of his approach. "So instead of passing ephemeral stack memory to the scheduler..."

"Precisely, Watson! We pass a proper Ruby object that lives on the heap. The scheduler can hold onto it, pass it to worker threads, call methods on it—all without fear of the memory disappearing from under our feet. The object controls its own lifetime, giving us complete mastery over when the internal state is valid."

"But surely," I interjected, "we need some means of cancellation? What if the work must be stopped mid-execution?"

Holmes's eyes twinkled. "Ah, Watson! You begin to think like a true detective. Indeed, we require a comprehensive cancellation system."

## Chapter V: The Cancellation Conundrum

Inspired by Holmes's elegant solution, I found myself designing what I hoped would be a comprehensive cancellation system. "Holmes," I ventured, "what if we create a state machine with atomic transitions?"

I sketched out my proposal:

- `RB_FIBER_BLOCKING_OPERATION_QUEUED` for submitted but unstarted work
- `RB_FIBER_BLOCKING_OPERATION_EXECUTING` for work in progress
- `RB_FIBER_BLOCKING_OPERATION_COMPLETED` for finished operations
- `RB_FIBER_BLOCKING_OPERATION_CANCELLED` for terminated work

"The beauty of this approach," I explained as I outlined `rb_fiber_scheduler_blocking_operation_cancel`, "lies in the intelligence of the cancellation. Queued work is simply marked cancelled. Executing work triggers the unblock function. All protected by atomic operations for thread safety."

Holmes studied my implementation with evident approval, but I could see his keen analytical mind at work.

"Excellent design, Watson!" he exclaimed. "But might I suggest a refinement to the naming? The enum names don't quite match the function naming pattern. What if we added `SCHEDULER` and `STATUS` to make them fully consistent: `RB_FIBER_SCHEDULER_BLOCKING_OPERATION_STATUS_QUEUED` and so forth?"

I paused, immediately recognizing the brilliance of his observation. "Perfect consistency in naming conventions—the lifecycle nature becomes crystal clear, and the full qualification ensures these constants can never be confused with anything else in the codebase."

## Chapter VI: The Ghostly Memory Corruption

Just when victory seemed within our grasp, we encountered perhaps the most mysterious phenomenon of our entire investigation. The test began failing with the cryptic error:

```
Unknown error: 12893088
```

"Curious," Holmes murmured, his brow furrowed. "That number in hexadecimal is `0xc4bba0`—far too large for any errno value. We have a case of memory corruption, Watson."

Through methodical analysis, Holmes traced the issue to its source: an uninitialized stack variable in `thread.c`. The state struct was allocated but not zeroed, leading to random garbage values.

"Elementary," he said with satisfaction as he added the simple fix: `= {0}`. "Uninitialized memory is the bane of C programmers everywhere, yet so easily remedied with proper hygiene."

## Chapter VII: The Private Class Affair

As we refined our implementation, Holmes made another astute observation. "Watson, this `BlockingOperation` class—it's an implementation detail that has no business in the public API."

With surgical precision, he transformed the class from a public `Fiber::Scheduler::BlockingOperation` into an anonymous, internal-only class. But then, with characteristic foresight, he added a crucial protection:

"An anonymous class," he explained, "is vulnerable to garbage collection. We must register it as a GC root to ensure its survival."

The addition of `rb_gc_register_mark_object` completed this particular deduction.

## Chapter VIII: The Windows Compilation Crisis

Our final challenge came from an unexpected quarter—the Windows platform, with its different compiler conventions. The build logs revealed multiple errors related to atomic operations:

```
error C4013: '__atomic_compare_exchange_n' undefined
error C2065: '__ATOMIC_SEQ_CST': undeclared identifier
```

"Ah," Holmes said immediately upon seeing the errors, "we've been using GCC-specific atomic intrinsics. Windows requires a different approach."

With characteristic resourcefulness, he delved into Ruby's own atomic abstractions, replacing our platform-specific code with Ruby's cross-platform equivalents:

- `__atomic_compare_exchange_n` became `RUBY_ATOMIC_CAS`
- `__atomic_load_n` became `RUBY_ATOMIC_LOAD`
- `__atomic_store_n` became `RUBY_ATOMIC_SET`

"The beauty of abstraction, Watson," he remarked as the final pieces fell into place, "is that it allows us to write once and run everywhere."

## Epilogue: The Completed Case

As I write these words, our blocking operations system stands as a testament to the power of methodical investigation and elegant engineering. We have achieved:

- **GVL Safety**: A clean interface preventing violations in work pools
- **Complete Cancellation**: Thread-safe cancellation with proper state management
- **Clean Public API**: Minimal, intuitive extract/execute/cancel functions
- **Memory Efficiency**: Single state storage without duplication
- **Cross-Platform Compatibility**: Support for Windows, macOS, Linux, and beyond
- **Thread Safety**: All operations safe for native thread pools

"Another case closed, Watson," Holmes said with quiet satisfaction as our final test passed with flying colors. "From a simple test execution to a complete architectural overhaul—such is the nature of true detective work in the realm of systems programming."

I could only marvel at the journey we had taken together, from that first mysterious test to this elegant, production-ready solution. Once again, Holmes had demonstrated that with patience, precision, and logical deduction, even the most complex mysteries yield their secrets to the determined investigator.

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*June 2025*
