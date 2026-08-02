# The Case of the Interrupt That Arrived Too Soon: A Ruby Mystery

*Being an account of a signal which arrived in the narrow interval between deciding to sleep and actually doing so, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Worker Which Missed Its Cue

The Falcon worker had completed its request when the supervisor sent <code class="language-plain">SIGINT</code>, beginning the normal graceful-shutdown sequence. One worker cleaned up and exited. Another remained inside its event selector until the supervisor's later escalation ended it.

“The worker ignored the signal,” I declared.

Holmes turned from the terminal. “What evidence would distinguish an ignored signal from a received signal awaiting delivery?”

The backtrace placed the delayed worker inside <code class="language-ruby">IO::Event::Selector::KQueue#select</code>. We sent a separate diagnostic signal to obtain another dump. The native wait returned, Ruby immediately noticed an already-pending <code class="language-ruby">Interrupt</code>, and the worker followed its cleanup path.

“Then <code class="language-plain">SIGINT</code> was not lost,” I said. “Ruby had remembered it.”

“But the thread went to sleep before it could act upon that memory.”

This was not a general failure of Falcon shutdown. It was an intermittent delay which required a signal to land during a very small transition inside the event loop. Under a typical supervisor the worker would eventually receive <code class="language-plain">SIGKILL</code>; the mystery was why it occasionally missed the graceful path.

## Chapter II: Why Not Raise Immediately?

“If Ruby knows an <code class="language-ruby">Interrupt</code> is pending,” I asked, “why not raise it at once?”

Holmes opened a scheduler queue midway through an update. “What if it arrives here?”

An asynchronous exception can appear between almost any two instructions. Raising it while a library is updating a queue, releasing a resource, or changing scheduler state can leave an invariant half-finished. Ruby therefore provides <code class="language-ruby">Thread.handle_interrupt</code>, allowing selected exceptions to be deferred until a controlled boundary.

Async uses that facility so a signal requests cancellation without tearing through internal synchronization at an arbitrary point.

“So deferred does not mean discarded,” I said. “The exception waits in the thread's pending-interrupt queue.”

“Precisely. The scheduler must continue running until it reaches the boundary where delivery is allowed.”

An earlier inconsistency had complicated this design: CRuby's default <code class="language-plain">SIGINT</code> path raised <code class="language-ruby">Interrupt</code> directly instead of using that queue. [Bug #22133](https://bugs.ruby-lang.org/issues/22133) and [the corresponding Ruby fix](https://github.com/ruby/ruby/pull/17533) made the default signal respect <code class="language-ruby">Thread.handle_interrupt</code> like other asynchronous exceptions.

That gave us predictable deferral. It also made the selector's responsibility clearer: a masked exception need not raise immediately, but it must prevent the scheduler from sleeping past the opportunity to handle it.

## Chapter III: The Sensible Check

Event selectors such as <code class="language-plain">kqueue</code>, <code class="language-plain">epoll</code>, and <code class="language-plain">io_uring</code> may wait in the kernel without a timeout. CRuby releases the Global VM Lock around that wait so other Ruby threads can run.

On older Ruby versions, <code class="language-ruby">IO::Event</code> checked for a queued exception before entering the native wait:

```ruby
return unless Thread.pending_interrupt?
```

“That appears sufficient,” I said. “If an interrupt is pending, do not sleep. Otherwise, sleep.”

Holmes wrote the operations separately:

```text
check Ruby's pending-interrupt queue
release the GVL
install the native unblock function
enter kevent/epoll/io_uring wait
```

“At which line does this become one indivisible decision?” he asked.

It did not. A signal could arrive after <code class="language-ruby">Thread.pending_interrupt?</code> returned false but while Ruby was entering the no-GVL region. Ruby would process the signal, place the masked exception in the pending queue, and continue the transition.

“But the signal should interrupt <code class="language-plain">kevent</code>,” I objected.

“Only if the native wait has begun, or Ruby has installed the unblock function which can wake it. What if the signal is handled in the interval before either is true?”

The exception could become pending too late for the preliminary check and too early to wake the native operation. The selector would then enter a wait with no second operating-system signal guaranteed to disturb it.

## Chapter IV: Catching the Interval

Our first attempts to observe the race changed its timing. Holmes reduced the experiment to many short Falcon worker lifecycles: complete one request, send <code class="language-plain">SIGINT</code>, and record any worker which did not leave promptly.

Native instrumentation eventually captured the ordering on the compatibility path:

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

“Which lock protects Ruby's pending-interrupt queue and the installation of its unblock function?”

That state belonged to CRuby. An extension could ask whether an interrupt was pending, but it could not safely make that query atomic with Ruby's internal transition.

The solution was therefore a Ruby C API rather than another selector-side check. [The new <code class="language-c">RB_NOGVL_PENDING_INTR_FAIL</code> flag](https://github.com/ruby/ruby/pull/17553) extends <code class="language-c">rb_nogvl</code> with a precise contract: if the current thread already has pending interrupts, including masked ones, do not invoke the native blocking callback.

“So Ruby itself performs the test while entering the blocking region,” I said.

“Yes. It can coordinate the pending queue and the unblock function under the lock which governs both.”

Instrumentation on Ruby with the new flag caught the same timing without entering the native wait:

```text
before transition: no pending interrupt
signal SIGINT
after transition: callback not entered, interrupt pending
```

The selector returned control to Ruby. The surrounding <code class="language-ruby">Thread.handle_interrupt</code> mask still decided when the exception could be raised; the new flag prevented deferral from becoming accidental sleep.

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

A KQueue benchmark found no measurable latency change. The older-Ruby fallback does allocate one internal object for each genuinely blocking wait; Ruby with the native flag retains the direct path. That is a concrete compatibility cost, rather than a claim that the workaround is free.

“And we should not say the worker previously waited forever,” I added. “The supervisor would escalate to <code class="language-plain">SIGKILL</code>.”

“Correct. State the result at its proper scale: an obscure race could delay graceful shutdown until escalation. The fix makes the intended cleanup path reliable.”

## Epilogue: State and Sleep Must Agree

“I trusted the pending-interrupt check because it always answered truthfully,” I said.

“It answered a question about one instant,” Holmes replied. “The selector acted in another.”

Whenever one thread decides whether it is safe to sleep while another can publish work, cancellation, or an interrupt, the decision and the transition to sleep must share an atomic protocol. Correct observations composed without coordination can still produce an incorrect system.

Holmes folded the timing trace and placed it in the casebook.

“The interrupt did not arrive too late to wake the worker, Watson. It arrived too soon for the mechanism which would have remembered to wake it.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
