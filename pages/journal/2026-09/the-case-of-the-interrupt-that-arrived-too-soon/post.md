# The Case of the Interrupt That Arrived Too Soon: A Ruby Mystery

*Being an account of a signal which arrived in the narrow interval between deciding to sleep and actually doing so, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Worker Which Missed Its Cue

[Falcon's new Cluster service](https://github.com/socketry/falcon/pull/356) allows each worker to bind its own listener and operate as an independently discoverable backend. While reviewing that work, we ran a focused lifecycle test: start two workers, complete a request, and stop the cluster.

“The test passed,” I said.

“How long did it take?”

I examined the timing. “More than ten seconds.”

The logs showed that the supervisor had sent <code class="language-plain">SIGINT</code> to both workers. One logged <code class="language-plain">Scheduler interrupted</code>, cleaned up, and exited. The other remained alive until the grace period expired and the supervisor escalated to <code class="language-plain">SIGKILL</code>. The assertions had passed without noticing that shutdown was forced.

“The new cluster service has broken shutdown,” I concluded.

“Perhaps,” Holmes replied. “Or perhaps two workers have merely given an older fault another opportunity to reveal itself.”

We built a stress reproduction around the same completed-request sequence. Request processing had finished before shutdown, yet nine of one hundred runs still killed exactly one worker while its sibling exited normally.

Shortly before escalation, the harness sent <code class="language-plain">SIGUSR1</code> to capture the delayed worker's stack. The backtrace placed it inside <code class="language-ruby">IO::Event::Selector::KQueue#select</code>. The diagnostic signal also released the native wait; Ruby immediately noticed an already-pending <code class="language-ruby">Interrupt</code>, and the worker followed its cleanup path.

“Then <code class="language-plain">SIGINT</code> was not lost,” I said. “Ruby had remembered it.”

“But the thread went to sleep before it could act upon that memory.”

The cluster work had exposed the failure, but the evidence now pointed below Falcon's request lifecycle. The mystery was how a graceful-shutdown interrupt could already be pending while the event selector remained asleep.

## Chapter II: Why Not Raise Immediately?

“If Ruby knows an <code class="language-ruby">Interrupt</code> is pending,” I asked, “why not raise it at once?”

Holmes opened a scheduler queue midway through an update. “What if it arrives here?”

An asynchronous exception can appear between almost any two instructions. Raising it while a library is updating a queue, releasing a resource, or changing scheduler state can leave an invariant half-finished. Ruby therefore provides <code class="language-ruby">Thread.handle_interrupt</code>, allowing selected exceptions to be deferred until a controlled boundary.

Async uses that facility so a signal requests cancellation without tearing through internal synchronization at an arbitrary point.

“So deferred does not mean discarded,” I said. “The exception waits in the thread's pending-interrupt queue.”

“Precisely. The scheduler must continue running until it reaches the boundary where delivery is allowed.”

“But had the default <code class="language-plain">SIGINT</code> always entered that queue?” Holmes asked.

It had not. CRuby's default signal path raised <code class="language-ruby">Interrupt</code> directly, allowing it to break through a <code class="language-ruby">Thread.handle_interrupt</code> mask. [Bug #22133](https://bugs.ruby-lang.org/issues/22133) and [the corresponding Ruby fix](https://github.com/ruby/ruby/pull/17533) routed the default signal through the pending-interrupt queue instead.

After that correction, <code class="language-plain">SIGINT</code> could be deferred consistently. In our delayed worker, the exception was waiting exactly where Ruby promised. That exposed the next question: how had the selector gone to sleep while it was pending?

## Chapter III: The Sensible Check

Event selectors such as <code class="language-plain">kqueue</code>, <code class="language-plain">epoll</code>, and <code class="language-plain">io_uring</code> may wait in the kernel without a timeout. CRuby releases the Global VM Lock around that wait so other Ruby threads can run.

On older Ruby versions, <code class="language-ruby">IO::Event</code> used a separate Ruby-level query before entering the native wait. Conceptually, the guard was:

```ruby
return if Thread.pending_interrupt?
```

“That appears sufficient,” I said. “If an interrupt is pending, do not sleep. Otherwise, sleep.”

Before examining the sequence, Holmes identified the unblock function: a callback CRuby installs so an interrupt arriving after a native operation begins can wake it. He translated the transition into conceptual Ruby pseudocode:

```ruby
# IO::Event, while holding the GVL:
return if Thread.pending_interrupt?

# Inside rb_thread_call_without_gvl2:
check_vm_interrupt_state

interrupt_lock.synchronize do
	install_unblock_function {selector.wake}
end

release_gvl

# IO::Event's native callback:
selector.wait(timeout: nil)
```

“At which line does this become one indivisible decision?” he asked.

It did not. A signal could arrive after <code class="language-ruby">Thread.pending_interrupt?</code> returned false but while Ruby was entering the no-GVL region. The outer mask deferred the exception into the pending queue. Once Ruby had processed that state, the VM interrupt flag could be cleared even though the exception remained queued.

“But the signal should interrupt <code class="language-plain">kevent</code>,” I objected.

“Only if the native wait has begun. The unblock function protects an interrupt which arrives after it is installed; it cannot replay a signal Ruby has already handled.”

The preliminary answer was now stale, while the no-GVL transition could see no active VM interrupt. It installed the unblock function and entered the wait, but no second operating-system signal was guaranteed to invoke it.

## Chapter IV: Catching the Interval

The stress harness showed us where the worker stopped, but not how it crossed from a pending interrupt into the native wait. Ordinary logging changed the timing, so we instrumented the selector and Ruby's no-GVL transition instead.

Native instrumentation eventually captured the ordering on the older-Ruby path:

```text
pending-interrupt check: false
signal SIGINT
native callback entered, pending queue: true
kevent(timeout: forever)
```

“Then move the check immediately before <code class="language-c">rb_thread_call_without_gvl2</code>,” I said. “There will be almost no interval left.”

“Almost?” Holmes asked.

We tried it. Across 2,000 iterations, the delay still appeared. Ruby could process the signal during the transition inside <code class="language-c">rb_thread_call_without_gvl2</code>, after any external predicate had returned.

“The check is accurate,” I admitted. “The native wait is also behaving correctly. The bug belongs to the gap between two correct operations.”

“And narrowing a race is not the same as closing it.”

## Chapter V: An Atomic Doorway

“Then <code class="language-ruby">IO::Event</code> needs to hold a lock around its check and the no-GVL transition,” I proposed.

“Can an extension hold the GVL while also participating in Ruby's interrupt-lock protocol?”

That transition belonged to CRuby. An extension could ask whether an interrupt was pending, but it could not safely make that query part of Ruby's internal move into a blocking region.

The solution was therefore a Ruby C API rather than another selector-side check. [The new <code class="language-c">RB_NOGVL_PENDING_INTR_FAIL</code> flag](https://github.com/ruby/ruby/pull/17553) extends <code class="language-c">rb_nogvl</code> with a precise contract: if the current thread already has pending interrupts, including masked ones, do not invoke the native blocking callback.

“So Ruby itself performs the test while entering the blocking region,” I said.

“Yes. But the pending queue and the VM interrupt flag are distinct evidence. Ruby must account for both before it commits to sleep.”

Holmes set the old and new transitions beside one another. In simplified Ruby-like pseudocode, <code class="language-c">rb_thread_call_without_gvl2</code> had entered the blocking region like this:

```ruby
check_vm_interrupt_state

interrupt_lock.synchronize do
	install_unblock_function {selector.wake}
end

release_gvl
selector.wait(timeout: nil)
```

With <code class="language-c">RB_NOGVL_PENDING_INTR_FAIL</code>, <code class="language-c">rb_nogvl</code> also examines the pending-exception queue while it still holds the GVL:

```ruby
if pending_interrupt?
	set_errno(0)
	return nil
end

loop do
	return nil if vm_interrupt?
	return nil if pending_interrupt?

	interrupt_lock.lock

	if vm_interrupt?
		interrupt_lock.unlock
		next
	end

	install_unblock_function {selector.wake}
	interrupt_lock.unlock
	break
end

release_gvl
selector.wait(timeout: nil)
```

“The second pending check is inside the guarded transition,” I observed.

“And the loop closes the remaining interval. If a VM interrupt appears while Ruby acquires the interrupt lock, it retries instead of installing the unblock function from stale state.”

When either pending-interrupt check fails, <code class="language-c">rb_nogvl</code> returns <code class="language-c">0</code> without invoking the selector callback and leaves <code class="language-c">errno</code> as zero. It does not report <code class="language-c">EINTR</code>, because no system call began and nothing was interrupted.

With the new flag, the same timing followed a different path. If <code class="language-plain">SIGINT</code> entered the pending queue during the transition, Ruby detected it before releasing the GVL and returned without invoking the selector callback. The surrounding <code class="language-ruby">Thread.handle_interrupt</code> mask still decided when the exception could be raised; the new flag prevented deferral from becoming accidental sleep.

## Chapter VI: The Older-Ruby Problem

“Case closed for the next Ruby release,” I said.

Holmes indicated the installed Ruby 4.0 interpreter. “And what of the applications running today?”

At the time of the investigation, the new flag existed in Ruby's development branch but not in released Ruby 4.0 versions. <code class="language-ruby">IO::Event</code> needed a preferred native path for future Ruby and a safe compatibility path for existing installations.

“Could the fallback poll with a short timeout?” I asked.

“It would avoid an unbounded native wait, but every idle event loop would wake periodically. Can Ruby's existing interrupt machinery refresh the state at the transition instead?”

[The <code class="language-ruby">IO::Event</code> fix](https://github.com/socketry/io-event/pull/204) centralized native selector waits behind one helper:

1. When <code class="language-c">RB_NOGVL_PENDING_INTR_FAIL</code> is available, it calls <code class="language-c">rb_nogvl</code> with the atomic flag.
2. On older Ruby, it enters a C-backed <code class="language-ruby">Thread.handle_interrupt(SignalException => :never)</code> block immediately around <code class="language-c">rb_thread_call_without_gvl2</code>.

“Why install another <code class="language-ruby">:never</code> mask when the signal is already masked?” I asked.

“Because pushing the inner mask refreshes Ruby's pending-interrupt state. The C-backed block then proceeds directly into the native transition without another Ruby safe point.”

Ruby either notices the pending exception before sleeping or installs the unblock function in time for a newly arriving signal to wake the selector. The outer Async mask continues to control delivery, so the compatibility path does not turn graceful cancellation into an exception at an arbitrary internal point.

The helper serves KQueue, EPoll, and URing. KQueue revealed the race, but the violated rule concerned every backend entering a native wait.

## Chapter VII: How Many Quiet Runs Are Enough?

The revised implementation survived a hundred iterations without delay.

“A convincing result?” I asked.

“How often did the original fail?” Holmes replied.

“Rarely.”

“Then a small quiet sample proves very little.”

We kept the original shutdown shape and multiplied the opportunities for the signal to strike the transition. The compatibility implementation completed 2,000 iterations with two workers per iteration and no delayed worker dumps or shutdown failures. Focused selector tests covered interrupts pending before a wait and arriving during it.

A KQueue benchmark on Ruby 4.0.5 measured 27.152 microseconds per wait for the baseline and 27.128 for the fallback, a difference of −0.09 percent and well within noise. The older-Ruby fallback does allocate one internal object for each genuinely blocking wait; Ruby with the native flag retains the direct path.

“The compatibility path closes the race on released Rubies,” I said, “and the benchmark found no measurable latency penalty.”

“While future Ruby can enforce the same rule directly at the doorway.”

## Epilogue: State and Sleep Must Agree

“I trusted the pending-interrupt check because it always answered truthfully,” I said.

“It answered a question about one instant,” Holmes replied. “The selector acted in another.”

Whenever one thread decides whether it is safe to sleep while another can publish work, cancellation, or an interrupt, the decision and the transition to sleep must share an atomic protocol. Correct observations composed without coordination can still produce an incorrect system.

Holmes folded the timing trace and placed it in the casebook.

“The interrupt did not arrive too late, Watson. It arrived too soon—between deciding to sleep and arranging to be woken.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*September 2026*
