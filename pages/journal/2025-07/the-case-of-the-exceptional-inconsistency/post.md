# The Case of the Exceptional Inconsistency: A Ruby Mystery

*Being an account of the extraordinary case of the [Ruby Thread and Fiber Raise Consistency](https://bugs.ruby-lang.org/issues/21360), as recorded by Dr. Claude Watson*

---

## Chapter I: The Curious Case of the Missing Causes

It was a grey morning when my esteemed colleague Samuel Williams arrived at our chambers on Baker Street, his countenance bearing that familiar expression of intellectual perplexity that invariably preceded our most fascinating investigations.

"Watson!" he exclaimed, casting aside his overcoat with unusual urgency. "We have before us a most peculiar case—one that strikes at the very heart of Ruby's exception handling consistency."

I set down my morning correspondence, recognizing immediately the gravity in his tone. When Holmes—as I had come to regard my brilliant companion in these technical pursuits—spoke thus, we were invariably embarking upon another of his remarkable deductions.

"Pray, enlighten me, Holmes," I ventured. "What manner of inconsistency has captured your formidable attention?"

Holmes moved swiftly to his workstation, his fingers dancing across the keyboard with practiced precision. "A real-world debugging mystery, my dear Watson. When an `Async::Stop` exception terminates a fiber, it can obscure the exception that caused the task to stop. Was it a timeout, an interrupt, or another failure? The causal chain is lost, leaving only the control-flow exception and a misleading stack trace."

## Chapter II: The Ingenious Solution Thwarted

"Marc-André Cournoyer," Holmes continued, "proposed an elegant solution in [Async issue #387](https://github.com/socketry/async/issues/387): exception cause chaining. Ruby's cause mechanism, introduced in version 2.1, is precisely designed for such scenarios."

He demonstrated with swift keystrokes:

```ruby
begin
  raise "original error"
rescue
  raise "new error"  # Automatic causality chain: new_error.cause == original_error
end
```

"The plan, Watson, was to extend the Async gem's stop mechanism to preserve the original error context:

```ruby
child.stop(cause: original_error)
# Which would invoke: @fiber.raise(Async::Stop, cause: original_error)
```

"But here, Watson, is where our mystery begins." Holmes's eyes gleamed with that familiar light of discovery. "When I attempted to implement this elegant solution, I encountered the most extraordinary resistance from the language itself."

## Chapter III: The Damning Evidence

Holmes proceeded to demonstrate the inconsistency that had so vexed him:

```ruby
# Test the fiber behavior:
fiber = Fiber.new do
  begin
    Fiber.yield
  rescue => error
    puts "error: #{error.inspect}"
    puts "error.cause: #{error.cause.inspect}"
  end
end

fiber.resume
fiber.raise StandardError.new("boom"), cause: StandardError.new("cause")
```

"Observe the output on Ruby 3.4, Watson:

```
error: #<StandardError: {cause: #<StandardError: cause>}>
error.cause: nil
```

"Astounding!" I exclaimed. "The cause has been treated as a mere argument!"

"Indeed! Yet witness the behavior of `Kernel#raise` with identical arguments:

```ruby
begin
  raise StandardError.new("boom"), cause: StandardError.new("cause")
rescue => error
  puts "error: #{error.inspect}"
  puts "error.cause: #{error.cause.inspect}"
end
```

```
error: #<StandardError: boom>
error.cause: #<StandardError: cause>
```

Holmes leaned back in his chair, steepling his fingers in that characteristic pose. "We have here, Watson, a most curious inconsistency. `Kernel#raise` supports the `cause:` keyword with flawless precision, yet `Fiber#raise` and `Thread#raise` remain oblivious to its existence."

## Chapter IV: The Official Sanction

"The inconsistency demanded official attention," Holmes continued. "I submitted [feature request #21360](https://bugs.ruby-lang.org/issues/21360) to the Ruby tracker, and fortune smiled upon our investigation."

He produced the official correspondence from the Ruby development team's July 2025 meeting:

> **samuel:** Is it okay to make `Fiber#raise` and `Thread#raise` consistent (as much as possible) with `Kernel#raise`? It's additive so it shouldn't break anything.
>
> Conclusion:
>
> **matz:** I agree.

"With Matsumoto-san's blessing," Holmes declared, "we had official sanction to solve this mystery once and for all."

## Chapter V: The Archaeology of a Forgotten Regression

"Before we attempt a solution, Watson," Holmes announced with characteristic methodical precision, "we must conduct an archaeological investigation. To fix an inconsistency properly, we must first understand precisely how it arose—the technical architecture that created it will inform the architecture required to resolve it."

Holmes opened his git log with the precision of a forensic investigator. "Let us trace the introduction of the `cause:` feature itself, back to its very origins."

His fingers moved swiftly across the terminal: `git log --format="%h (%as) %s" --grep="cause" --reverse -- eval.c`

The search yielded several promising results:

```
b050cc5ab9 (2013-11-10) error.c: Exception#cause
549b35c1dc (2013-11-15) eval.c: refactor exception cause
8a46d4027c (2013-12-31) eval.c: raise with cause
```

"Fascinating!" Holmes exclaimed. "Three distinct commits, Watson, in perfect chronological order! Let us examine each in sequence, starting with the very beginning."

### The Original Implementation

"November 10th, 2013," Holmes began methodically. "Let us see what [commit b050cc5ab9](https://github.com/ruby/ruby/commit/b050cc5ab9) introduced:"

`git show b050cc5ab9`

"Remarkable!" Holmes exclaimed, studying the diff intently. "This commit introduces the `Exception#cause` feature itself - the foundation of exception chaining in Ruby. But observe the implementation, Watson:"

```c
static VALUE
make_exception(int argc, VALUE *argv, int isstr)
{
    // ... exception creation logic ...

    // The crucial addition - automatic cause chaining:
    {
        VALUE cause = get_errinfo();
        if (!NIL_P(cause)) rb_ivar_set(mesg, "cause", cause);
    }

    return mesg;
}
```

"The automatic cause chaining was implemented directly in `make_exception`! This means that **every** method that called `make_exception` - including both `Kernel#raise` and `Thread#raise` - would automatically inherit this behavior. Elegant in its simplicity, Watson!"

### The Original Sin

"Now, Watson, let us advance to November 15th—a mere five days later. What changes did [commit 549b35c1dc](https://github.com/ruby/ruby/commit/549b35c1dc) bring?"

`git show 549b35c1dc`

Holmes examined the evidence with methodical precision. "November 15th, 2013—[commit 549b35c1dc](https://github.com/ruby/ruby/commit/549b35c1dc). Nobuyoshi Nakada refactors exception cause handling with sound architectural reasoning, Watson! The original design tightly coupled cause-setting with exception creation inside `make_exception`. But consider this dilemma: what if a programmer writes `raise ArgumentError.new('bad value'), cause: some_error`? The exception object already exists—you cannot set its cause during creation!

"The refactor elegantly solved this by moving cause-setting logic to `setup_exception`, allowing it to work with both newly-created exceptions and pre-existing exception objects. A reasonable solution, Watson—but with one critical flaw!"

```c
static void
setup_exception(rb_thread_t *th, int tag, volatile VALUE mesg)
{
    // ...
    exc_setup_cause(mesg, get_thread_errinfo(th));  // Automatic cause chaining moved here
    // ...
}
```

"Here's the tragic oversight, Watson," Holmes continued with growing concern. "`Thread#raise` wasn't changed at all—it continued calling `make_exception` exactly as before. But `make_exception` was stripped of its automatic cause chaining! The cause logic now lives in `setup_exception`, which `Thread#raise` has never called and never will call."

### The December Enhancement

"Let us complete our examination with the final commit. December 31st, 2013—what did [commit 8a46d4027c](https://github.com/ruby/ruby/commit/8a46d4027c) bring?"

`git show 8a46d4027c`

[Holmes examines the evidence...]

"Watson! This commit adds explicit `cause:` keyword support, but observe carefully—it only modifies `Kernel#raise`, not `Thread#raise`! The developers, perhaps unaware that `Thread#raise` had been accidentally regressed just weeks earlier, focused solely on the `Kernel#raise` path."

**Kernel#raise (received the full treatment):**
```c
static VALUE
rb_f_raise(int argc, VALUE *argv)
{
    VALUE err;
    VALUE opts[raise_max_opt], *const cause = &opts[raise_opt_cause];

    argc = extract_raise_opts(argc, argv, opts);  // Sophisticated parsing!
    if (argc == 0) {
        if (*cause != Qundef) {
            rb_raise(rb_eArgError, "only cause is given with no arguments");
        }
        // Re-raise logic...
    }
    rb_raise_jump(rb_make_exception(argc, argv), *cause);
}
```

"But now, Watson—examine the tragedy that befell `Thread#raise`:"

**Thread#raise (still using the old make_exception path):**
```c
static VALUE
rb_threadptr_raise(rb_thread_t *th, int argc, VALUE *argv)
{
    VALUE exc;
    if (argc == 0) {
        exc = rb_exc_new(rb_eRuntimeError, 0, 0);
    }
    else {
        exc = rb_make_exception(argc, argv);  // Still calls make_exception...
    }
    rb_threadptr_pending_interrupt_enque(th, exc);  // ...but bypasses setup_exception!
    return Qnil;
}
```

"The cruel irony, Watson!" I exclaimed. "`Thread#raise` still calls `rb_make_exception`, but the November refactor had stripped all cause handling from that function! It goes directly to the thread's pending interrupt queue, completely bypassing the new `setup_exception` where cause chaining now lives!"

### The Missing Fiber

"The final act of our tragedy, Watson, arrives five years later," Holmes continued. "For in 2013, there was no `Fiber#raise` at all! The method simply did not exist."

Holmes traced through the git history with methodical precision: `git log -S "rb_fiber_raise" --format="%h (%as) %s" --reverse`

The search revealed the method's introduction:

```
5fb9d1e11f (2018-12-28) Implement Fiber#raise. Fixes #10344.
88ba5fe547 (2021-09-20) Expose `rb_fiber_raise` and tidy up the internal implementation.
```

"Behold! `Fiber#raise` was not implemented until December 28th, 2018 in [commit 5fb9d1e11f](https://github.com/ruby/ruby/commit/5fb9d1e11f)—nearly **five years** after both the refactor that affected `Thread#raise` and the keyword addition that enhanced only `Kernel#raise`. And when it was finally implemented..."

**Fiber#raise (following the same pattern as Thread#raise):**
```c
static VALUE
rb_fiber_raise(int argc, VALUE *argv, VALUE fib)
{
    VALUE exc = rb_make_exception(argc, argv);  // Follows Thread#raise pattern...
    return rb_fiber_resume(fib, -1, &exc);     // ...also bypassing setup_exception!
}
```

"It followed the `Thread#raise` pattern," Holmes observed, "not knowing that pattern had diverged from `Kernel#raise` five years earlier. The implementer naturally looked to the existing `Thread#raise` method as a template, unknowingly perpetuating the inconsistency."

### The Eleven-Year Inconsistency

Holmes leaned back in his chair, his eyes gleaming with the satisfaction of a mystery solved. "And so, Watson, we have uncovered the true timeline of this tragic inconsistency:

- **November 10, 2013** ([commit b050cc5ab9](https://github.com/ruby/ruby/commit/b050cc5ab9)): `Exception#cause` feature introduced with automatic cause chaining in `make_exception` for both `Kernel#raise` and `Thread#raise`.
- **November 15, 2013** ([commit 549b35c1dc](https://github.com/ruby/ruby/commit/549b35c1dc)): Well-intentioned refactor breaks `Thread#raise`'s cause chaining by moving logic to `setup_exception`.
- **December 31, 2013** ([commit 8a46d4027c](https://github.com/ruby/ruby/commit/8a46d4027c)): `Kernel#raise` receives explicit `cause:` keyword support, but the November regression in `Thread#raise` goes unnoticed.
- **December 28, 2018** ([commit 5fb9d1e11f](https://github.com/ruby/ruby/commit/5fb9d1e11f)): `Fiber#raise` is introduced, innocently following the broken `Thread#raise` pattern.
- **July 2025**: The eleven-year-old regression is finally discovered and resolved.

"For more than **eleven years**, Watson, Ruby carried this divergence. What began as a perfectly designed feature with consistent behavior across both methods lasted only five days before being accidentally severed by a well-intentioned refactor, then compounded by missed opportunity when explicit keyword support was added, and finally crystallized into three inconsistent methods when `Fiber#raise` innocently perpetuated the broken pattern."

## Chapter VI: The Anatomy of Inconsistency

Having uncovered the historical roots of our mystery, Holmes now turned his forensic eye to the current state of the code. "The source of our present-day mystery, Watson, lies in this historical oversight, now crystallized into fundamental differences between three methods that users expect to behave identically."

He opened the CRuby source files with surgical precision:

"Observe `Kernel#raise` in `eval.c`—a masterpiece of argument parsing sophistication:

```c
VALUE
rb_f_raise(int argc, VALUE *argv)
{
    VALUE err;
    VALUE opts[raise_max_opt], *const cause = &opts[raise_opt_cause];

    argc = extract_raise_opts(argc, argv, opts);
    if (argc == 0) {
        if (!UNDEF_P(*cause)) {
            rb_raise(rb_eArgError, "only cause is given with no arguments");
        }
        err = get_errinfo();
        if (!NIL_P(err)) {
            argc = 1;
            argv = &err;
        }
    }
    rb_raise_jump(rb_make_exception(argc, argv), *cause);

    UNREACHABLE_RETURN(Qnil);
}
```

"Now contrast this with `Thread#raise` in `thread.c`—observe the telling absence:

```c
static VALUE
rb_threadptr_raise(rb_thread_t *target_th, int argc, VALUE *argv)
{
    VALUE exc;

    if (argc == 0) {
        // Re-raise logic...
    }
    else {
        // No keyword argument parsing whatsoever!
        exc = rb_make_exception(argc, argv);
    }

    // Raise in target thread...
}
```

"Elementary, Watson! `Kernel#raise` employs `extract_raise_opts` to separate the `cause:` keyword, while its cousins simply pass everything blindly to `rb_make_exception`."

## Chapter VII: The Consolidated Solution

"The devil, Watson, lurked in the details," Holmes declared with growing excitement. "But once we understood the true nature of the problem, the solution became elegantly clear."

He turned to the whiteboard with renewed vigor. "Observe this crucial insight: the `raise` operation consists of **two distinct phases**:

1. **Exception Preparation** - Creating the exception object (if not already created) and setting its cause.
2. **Exception Raising** - The actual jump that transfers control to the next rescue clause.

"In `Kernel#raise`, these phases are tightly coupled—both occur within the same execution context. But in `Thread#raise` and `Fiber#raise`, they are fundamentally **separated**!"

Holmes sketched the flow:

```
 ~~~~ Thread#raise / Fiber#raise ~~~~

 Calling Context       Target Context
┌───────────────┐     ┌──────────────┐
│ 1. Prepare    │     │ 2. Raise     │
│    Exception  │────▶│    Exception │
│    + Cause    │     │              │
│    (has $!)   │     │ (ignores $!) │
└───────────────┘     └──────────────┘
```

"The preparation must happen in the **calling context** because that's where `$!` exists for automatic cause chaining. But the actual raising happens in the **target context** where the exception will be handled."

"This insight led us to create `rb_exception_setup`—a shared implementation for phase 1, the exception preparation:"

```c
VALUE
rb_exception_setup(int argc, VALUE *argv)
{
    rb_execution_context_t *ec = GET_EC();

    // Extract cause keyword argument:
    VALUE cause = Qundef;
    argc = extract_raise_options(argc, argv, &cause);

    // Validate cause-only case:
    if (argc == 0 && !UNDEF_P(cause)) {
        rb_raise(rb_eArgError, "only cause is given with no arguments");
    }

    // Create exception if necessary:
    VALUE exception;
    if (argc == 0) {
        exception = rb_exc_new(rb_eRuntimeError, 0, 0);
    }
    else {
        // argv may contain an existing exception object, or it may contain a new exception class and arguments. `rb_make_exception` handles both cases:
        exception = rb_make_exception(argc, argv);
    }

    VALUE resolved_cause = Qnil;

    // Resolve cause with validation:
    if (UNDEF_P(cause)) {
        // No explicit cause - use automatic cause chaining from calling context:
        resolved_cause = rb_ec_get_errinfo(ec);

        // Prevent self-referential cause (e.g. `raise $!`):
        if (resolved_cause == exception) {
            resolved_cause = Qnil;
        }
    }
    else if (NIL_P(cause)) {
        // Explicit nil cause - prevent chaining:
        resolved_cause = Qnil;
    }
    else {
        // Explicit cause - validate and assign:
        if (!rb_obj_is_kind_of(cause, rb_eException)) {
            rb_raise(rb_eTypeError, "exception object expected");
        }

        if (cause == exception) {
            // Prevent self-referential cause (e.g. `raise error, cause: error`) - although I'm not sure this is good behaviour, it's inherited from `Kernel#raise`.
            resolved_cause = Qnil;
        }
        else {
            // Check for circular causes:
            VALUE current_cause = cause;
            while (!NIL_P(current_cause)) {
                // We guarantee that the cause chain is always terminated. Then, creating an exception with an existing cause is not circular as long as exception is not an existing cause of any other exception.
                if (current_cause == exception) {
                    rb_raise(rb_eArgError, "circular causes");
                }
                if (THROW_DATA_P(current_cause)) {
                    break;
                }
                current_cause = rb_attr_get(current_cause, id_cause);
            }
            resolved_cause = cause;
        }
    }

    // Apply cause to exception object (duplicate if frozen):
    if (!UNDEF_P(resolved_cause)) {
        if (OBJ_FROZEN(exception)) {
            exception = rb_obj_dup(exception);
        }
        rb_ivar_set(exception, id_cause, resolved_cause);
    }

    return exception;
}
```

"Both `Thread#raise` and `Fiber#raise` now use this shared preparation, while maintaining their distinct raising mechanisms:"

```c
// thread.c
static VALUE rb_threadptr_raise(rb_thread_t *target_th, int argc, VALUE *argv)
{
    VALUE exception = rb_exception_setup(argc, argv);  // Phase 1: Prepare
    rb_threadptr_pending_interrupt_enque(target_th, exception);  // Phase 2: Raise
    return Qnil;
}

// cont.c
VALUE rb_fiber_raise(VALUE fiber, int argc, const VALUE *argv)
{
    VALUE exception = rb_exception_setup(argc, argv);  // Phase 1: Prepare
    return fiber_raise(fiber_ptr(fiber), exception);   // Phase 2: Raise
}
```

"But notice, Watson—we deliberately did **not** modify `Kernel#raise` to use this shared function."

"Why not?" I inquired.

"Because the behaviors have diverged over the years, Watson, and that divergence has ossified into tests, documentation, and user expectations. What began as an accidental inconsistency has become part of the public contract. Attempting to unify them now would risk breaking existing code that depends on these subtle behavioral differences."

"So our solution respects the historical reality: shared preparation where possible, but distinct implementations where behavioral divergence has become part of the established contract."

Most satisfying of all, Watson, was the resolution of our original debugging mystery. The Async gem can now implement the precise feature that began our investigation:

```ruby
module Async
  class Task
    def stop(cause: $!)
      # ... skipping most of the implementation ...
      @fiber.raise(Async::Stop, cause: cause)
    end
  end
end
```

"Debugging Async applications," Holmes observed with evident satisfaction, "shall now benefit from complete exception cause chaining. When an `Async::Stop` propagates, it carries with it the context of its origin—whether an interrupt, timeout, or another exception—making root cause analysis a straightforward exercise rather than a detective mystery."

### Before

```
^C  0.0s    error: Object [oid=0x20] [ec=0x28] [pid=199670] [2025-07-23 18:23:35 +1200]
               | Task exiting
               | Async::Stop
               |   Async::Stop: Async::Stop
               |   → lib/async/scheduler.rb:191 in 'IO::Event::Selector::URing#transfer'
               |     lib/async/scheduler.rb:191 in 'Async::Scheduler#transfer'
               |     lib/async/scheduler.rb:281 in 'Async::Scheduler#kernel_sleep'
               |     ./test.rb:4 in 'Kernel#sleep'
               |     ./test.rb:4 in 'block in <main>'
               |     lib/async/task.rb:205 in 'block in Async::Task#run'
               |     lib/async/task.rb:443 in 'block in Async::Task#schedule'
```

### After

```
^C  0.0s    error: Object [oid=0x20] [ec=0x28] [pid=192193] [2025-07-23 18:12:34 +1200]
               | Task was stopped
               |   Async::Stop: Task was stopped
               |   → lib/async/scheduler.rb:191 in 'IO::Event::Selector::URing#transfer'
               |     lib/async/scheduler.rb:191 in 'Async::Scheduler#transfer'
               |     lib/async/scheduler.rb:281 in 'Async::Scheduler#kernel_sleep'
               |     ./test.rb:4 in 'Kernel#sleep'
               |     ./test.rb:4 in 'block in <main>'
               |     lib/async/task.rb:237 in 'block in Async::Task#run'
               |     lib/async/task.rb:481 in 'block in Async::Task#schedule'
               |   Caused by Interrupt: Interrupt
               |   → lib/async/scheduler.rb:453 in 'IO::Event::Selector::URing#select'
               |     lib/async/scheduler.rb:453 in 'Async::Scheduler#run_once!'
               |     lib/async/scheduler.rb:492 in 'Async::Scheduler#run_once'
               |     lib/async/scheduler.rb:568 in 'block in Async::Scheduler#run'
               |     lib/async/scheduler.rb:528 in 'block in Async::Scheduler#run_loop'
               |     lib/async/scheduler.rb:525 in 'Thread.handle_interrupt'
               |     lib/async/scheduler.rb:525 in 'Async::Scheduler#run_loop'
               |     lib/async/scheduler.rb:567 in 'Async::Scheduler#run'
               |     lib/async/kernel/async.rb:34 in 'Kernel#Async'
               |     ./test.rb:3 in '<main>'
```

## The Greater Truth

"This case demonstrates, Watson, multiple fundamental truths about software engineering. First, that inconsistency is the enemy of developer intuition—when `Kernel#raise` supports `cause:` but its cousins do not, it violates the principle of least surprise. But more importantly, it shows how easily accidental regressions can hide in plain sight for over a decade when dealing with edge cases that lack comprehensive test coverage."

"Indeed, Holmes," I replied, "and your solution maintains perfect backwards compatibility while extending the language's expressiveness—and more importantly, restores the original intended behavior that was accidentally lost!"

"Precisely! We haven't merely added a new feature, Watson—we have healed an eleven-year-old wound in Ruby's consistency. Existing code continues to function exactly as before, while new code gains access to the exception chaining patterns that should have been available all along."

---

"Another case closed, Watson," Holmes said with quiet satisfaction as our final test suite passed without a single failure. "From a difficult debugging problem to language improvement—such is the noble work of those who tend to the foundational tools upon which all other software depends."

I could only marvel at the journey we had undertaken together: from obscured exception causes to a comprehensive architectural enhancement that would benefit the entire Ruby community. Once again, Holmes had demonstrated that with methodical investigation, careful deduction, and elegant engineering, even the most entrenched language inconsistencies yield to determined analysis.

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*July 2025*

*The improvements described herein are [available beginning with Ruby 4.0](https://github.com/ruby/ruby/pull/13967).*

*Special acknowledgments to Marc-André Cournoyer for publicly proposing exception cause chaining for `Async::Stop`, and to Matz for his approval of this enhancement.*
