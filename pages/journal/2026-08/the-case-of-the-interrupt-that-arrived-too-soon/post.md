# The Case of the Interrupt That Arrived Too Soon: A Ruby Mystery

*Being an account of a signal which arrived in the narrow interval between deciding to sleep and actually doing so, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Worker Which Missed Its Cue

The Falcon worker had completed its request. The supervisor sent <code class="language-plain">SIGINT</code>, beginning the normal graceful-shutdown sequence. One worker cleaned up and exited. Another remained inside its event selector until the supervisor's later escalation ended it.

This was not a general failure of Falcon shutdown. It was an intermittent delay which appeared only when the signal landed during a very small transition inside the event loop.

“The signal was delivered,” I said, studying the trace. “Why did the worker not act upon it?”

“Because delivery and action are not the same event,” Holmes replied.

The stuck worker's backtrace placed it in <code class="language-ruby">IO::Event::Selector::KQueue#select</code>. Sending another diagnostic signal woke the native wait; Ruby then noticed the already-pending <code class="language-ruby">Interrupt</code> and followed the intended cleanup path.

The interrupt had not been lost. The thread had gone to sleep at precisely the wrong moment.

## Chapter II: Why Ruby Defers Interrupts

Asynchronous exceptions can arrive between almost any two instructions. Raising one while a library is updating a queue, releasing a resource, or changing scheduler state can leave an invariant half-finished. Ruby therefore provides <code class="language-ruby">Thread.handle_interrupt</code>, which lets code defer selected exceptions until a controlled boundary.

Async uses that facility so signals request cancellation without tearing through internal synchronization at an arbitrary point. An earlier problem complicated this model: CRuby's default <code class="language-plain">SIGINT</code> path raised <code class="language-ruby">Interrupt</code> directly instead of placing it in the thread's pending-interrupt queue. [Bug #22133](https://bugs.ruby-lang.org/issues/22133) and [the corresponding Ruby fix](https://github.com/ruby/ruby/pull/17533) made the default signal respect <code class="language-ruby">Thread.handle_interrupt</code> like other asynchronous exceptions.

That correction made delivery predictable, but it also helped expose a second, subtler question: how should an event selector behave when a masked signal exception is pending?

It must return control to Ruby. The exception may remain deferred, but the scheduler needs an opportunity to reach the boundary where shutdown is handled.

## Chapter III: The Check Before Sleep

An event selector such as <code class="language-plain">kqueue</code>, <code class="language-plain">epoll</code>, or <code class="language-plain">io_uring</code> may wait in the kernel with no timeout. While it waits, CRuby releases the Global VM Lock so other Ruby threads can run.

On older Ruby versions, <code class="language-ruby">IO::Event</code> tried to avoid sleeping with a queued exception by checking first:

```ruby
return unless Thread.pending_interrupt?
```

Conceptually, the sequence was:

```text
check Ruby's pending-interrupt queue
release the GVL
install the native unblock function
enter kevent/epoll/io_uring wait
```

The check was sensible, but it was a separate operation. A signal could arrive after the check and be processed while Ruby transitioned into the no-GVL region. Because <code class="language-ruby">Thread.handle_interrupt</code> masked the resulting exception, Ruby queued it rather than raising it.

The selector could then begin its native wait without an unblock function having observed that earlier signal. No second operating-system signal was guaranteed to wake it.

## Chapter IV: Catching the Interval

The race resisted ordinary logging because instrumentation changed its timing. A stress reproduction ran many short Falcon worker lifecycles, sent <code class="language-plain">SIGINT</code> after a completed request, and dumped any worker which had not left promptly.

Native instrumentation eventually recorded the decisive ordering on the compatibility path:

```text
pending-interrupt check: false
signal SIGINT
native callback entered, pending queue: true
kevent(timeout: forever)
```

Moving the check closer to the no-GVL call did not close the gap. Across 2,000 iterations, workers could still hit it. The transition into <code class="language-c">rb_thread_call_without_gvl2</code> itself was a point where Ruby could process the signal.

“Then there is no correct place outside the door to check whether the room is occupied,” I said.

“Exactly,” said Holmes. “The check and the act of locking the door must be one operation.”

## Chapter V: An Atomic Doorway

CRuby needed an API which could inspect the pending queue as part of entering the no-GVL region. [The new <code class="language-c">RB_NOGVL_PENDING_INTR_FAIL</code> flag](https://github.com/ruby/ruby/pull/17553) provides that contract.

When passed to <code class="language-c">rb_nogvl</code>, the flag says: if this thread already has pending interrupts, including masked ones, do not invoke the native blocking callback. Ruby performs the decision inside its own transition machinery, where it can coordinate the pending queue and the unblock function under the appropriate lock.

Instrumentation on Ruby with the new flag caught the race cleanly:

```text
before transition: no pending interrupt
signal SIGINT
after transition: callback not entered, interrupt pending
```

The important result was not that <code class="language-ruby">Interrupt</code> suddenly raised inside a protected section. The selector returned control to Ruby, while the surrounding mask continued to determine when the exception could be delivered.

## Chapter VI: A Path for Released Rubies

At the time of the investigation, the new C flag was available in Ruby's development branch but not in released Ruby 4.0 versions. <code class="language-ruby">IO::Event</code> therefore needed both a preferred path for future Ruby and a safe compatibility path for existing installations.

[The <code class="language-ruby">IO::Event</code> fix](https://github.com/socketry/io-event/pull/204) centralized native selector waits behind one helper:

1. When <code class="language-c">RB_NOGVL_PENDING_INTR_FAIL</code> is available, it calls <code class="language-c">rb_nogvl</code> with the atomic flag.
2. On older Ruby, it enters a C-backed <code class="language-ruby">Thread.handle_interrupt(SignalException => :never)</code> block immediately around <code class="language-c">rb_thread_call_without_gvl2</code>.

Pushing that inner mask refreshes Ruby's pending-interrupt state. Because the block proceeds directly into the native transition without another Ruby safe point, Ruby either notices the pending exception before sleeping or installs the unblock function in time for a newly arriving signal to wake the selector. The outer Async mask still controls actual exception delivery.

The helper is shared by KQueue, EPoll, and URing, so the fix does not depend on the backend which happened to reveal the race.

## Chapter VII: Proving a Negative

Timing bugs invite overconfident conclusions. A hundred successful runs prove little when the failure is rare. The validation therefore kept the original shutdown shape and increased the opportunities for the signal to strike the transition.

The compatibility implementation completed 2,000 iterations with two workers per iteration and no delayed worker dumps or shutdown failures. Focused selector tests exercised interrupts pending before a wait and arriving during it. A small KQueue benchmark found no measurable latency change; the older-Ruby fallback does allocate one internal object for each genuinely blocking wait, while Ruby with the native flag retains the direct path.

The result should be stated narrowly. The change closes an obscure race in graceful shutdown. Before the fix, a worker which struck that interval would not remain alive without limit under a typical supervisor: escalation would eventually send <code class="language-plain">SIGKILL</code>. The value of the fix is that Ctrl-C and deployment termination can reliably take the graceful path instead of occasionally requiring that escalation.

## Epilogue: State and Sleep Must Agree

Concurrency defects often hide between operations which are individually correct. <code class="language-ruby">Thread.pending_interrupt?</code> answered its question accurately. The selector's native wait behaved correctly. The failure lived in the interval between them.

Whenever one thread decides whether it is safe to sleep while another can publish work, cancellation, or an interrupt, the decision and the transition to sleep must share an atomic protocol. Checking first is not enough.

Holmes folded the timing trace and placed it in the casebook.

“The interrupt did not arrive too late to wake the worker, Watson. It arrived too soon for the mechanism which would have remembered to wake it.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
