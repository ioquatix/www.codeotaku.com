# The Case of the Missing Line: A Ruby Mystery

*Being an account of a line of Ruby which certainly executed but left no trace of having done so, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Impossible Trace

Holmes handed me a program containing three executable lines:

```ruby
raise if 1 == 2
while true
  break
end
```

“The first condition is false,” I said. “The second is true, so the body executes and breaks from the loop.”

“Then which lines should <code class="language-ruby">TracePoint.new(:line)</code> report?”

“One, two, and three.”

He turned the terminal toward me:

```ruby
[1, 3]
```

“Perhaps Ruby optimized the loop condition away,” I suggested. “<code class="language-ruby">true</code> is constant.”

Holmes replaced it with a real predicate:

```ruby
def read
  return if @finished

  while chunk = super
    consume(chunk)
  end
end
```

The loop condition called <code class="language-ruby">super</code>, assigned its result, and plainly executed. Its line event was still absent. [Bug #22218](https://bugs.ruby-lang.org/issues/22218) reproduced the behavior on Ruby 3.3, 3.4, and 4.0.

“Then the line did not fail to execute,” I said. “It failed to leave evidence.”

“A useful distinction, Watson. Our program's result is correct; its account of how it reached that result is not.”

## Chapter II: What Does a Line Event Promise?

“Must every executed expression produce a line event?” I asked.

“No. If we assume the wrong contract, we shall diagnose a compliant optimization as a defect.”

<code class="language-ruby">TracePoint</code> allows debuggers, tracers, profilers, and diagnostic tools to observe events inside Ruby execution. A <code class="language-ruby">:line</code> event does not fire for every subexpression. It marks the source lines which Ruby's compiled instruction sequence identifies as execution points.

“Then perhaps line two simply is not such a point.”

Holmes indicated the loop condition. “A debugger stepping through <code class="language-ruby">while chunk = super</code> must be able to associate that call and assignment with its source line. More decisively, Ruby's own compiler attached a line event to the bytecode for it. The event existed before optimization.”

That mapping is part of the tooling contract. Developers rely on it to step through methods, explain which branches ran, and connect runtime behavior to source. Coverage consumes related metadata, but an ordinary TracePoint user does not necessarily enable coverage.

The question therefore moved down one level: where had the event-bearing instruction gone?

## Chapter III: The Shortened Route

CRuby compiles Ruby source into YARV instructions. Event flags attached to selected instructions tell the interpreter when to notify TracePoint and Coverage.

Holmes sketched the relevant control flow:

```text
conditional branch -> jump carrying line-two event
jump carrying event -> loop body
```

“A branch leading to a jump,” I said. “The compiler can point the branch directly at the loop body.”

“And ordinarily it should. What do we call that?”

“Jump-to-jump peephole optimization.”

The shortened route was:

```text
conditional branch -> loop body
```

“The destination is unchanged,” I said. “So the optimization preserves program behavior.”

“Which behavior?” Holmes asked.

I saw the omission. The resulting values and control flow were equivalent, but execution no longer visited the intermediate instruction carrying the line event. To the program, the road was shorter. To an observer mapping the journey, a signpost had vanished.

“An optimization can preserve the answer while changing what an instrumentation API observes,” I said.

“And if observation is part of the supported semantics, the compiler must preserve that too.”

## Chapter IV: The Coverage Alibi

We enabled line coverage. To my surprise, line two reappeared.

“Then TracePoint is broken, but Coverage is not?” I asked.

“Or the same compiler contains a safeguard which only Coverage activates.”

[Bug #15980](https://bugs.ruby-lang.org/issues/15980) had previously found that this jump optimization could make line coverage inaccurate. Ruby already stopped the optimization when line coverage was enabled and the skipped instruction carried event metadata.

The compiler source documented the compromise. Coverage received the guard; ordinary <code class="language-ruby">TracePoint</code> line events could still miss the loop condition.

“So the bytecode depends on who asks to observe it,” I said. “Coverage keeps the event-bearing jump, while a standalone TracePoint receives the optimized route.”

“Exactly. The prior fix proves that the event is meaningful. Its condition also explains why our two observers disagree.”

The clue narrowed the remedy. We did not need a new concept of source lines. We needed the existing protection to follow the line event itself, rather than the particular tool which happened to request it.

## Chapter V: How Much Machinery Is Necessary?

An [earlier proposal](https://github.com/ruby/ruby/pull/17825) explored representing the control-flow edge more explicitly so the event could survive optimization.

“That sounds comprehensive,” I said.

“It also asks the interpreter and JITs to understand new metadata,” Holmes replied. “Before adding machinery, what is the smallest rule which preserves the evidence?”

The answer was to retain the existing intermediate jump whenever removing it would erase a line event. [The merged fix](https://github.com/ruby/ruby/pull/18122) changed the peephole condition to stop this specific retargeting when the skipped instruction carries <code class="language-c">RUBY_EVENT_LINE</code> or <code class="language-c">RUBY_EVENT_COVERAGE_LINE</code>:

```c
int stop_optimization =
    nobj->link.type == ISEQ_ELEMENT_INSN &&
    (nobj->insn_info.events &
        (RUBY_EVENT_LINE | RUBY_EVENT_COVERAGE_LINE));
```

“Other jump chains are still folded,” I observed. “Only a jump carrying observable evidence is retained.”

“A narrow rule for a narrow contract.”

With that route restored, the original program produced the expected trace:

```ruby
[1, 2, 3]
```

## Chapter VI: The Price of Preserving a Signpost

“We have made the trace correct,” I said. “But the interpreter must now dispatch an additional jump.”

“How expensive is it?”

“One instruction. Surely negligible.”

Holmes raised an eyebrow. “That is an opinion, not a measurement.”

Targeted benchmarks concentrated the affected pattern until nearly every iteration or method call traversed the retained jump. The interpreter slowed by about one percent in a hot loop and 2.7 percent in a minimal guarded reader.

“Larger than I expected,” I admitted. “Should we accept incorrect tracing to keep the optimization?”

“You offer a false choice. Must every execution engine preserve the jump in the same form?”

YJIT and ZJIT operate after the bytecode has preserved its event semantics. YJIT can place the target block next and emit no machine jump; ZJIT can clean the redundant chain from its control-flow graph. The guarded-reader benchmark showed no repeatable JIT regression.

The division of responsibility became clear: bytecode remains complete for the interpreter and instrumentation, while a JIT may reorganize machine control flow without discarding promised observations.

“Then the interpreter figures are real but deliberately concentrated upper bounds,” I said, “not an estimate of general application slowdown.”

“Precisely. Neither hide the cost nor exaggerate its reach.”

## Chapter VII: Testing the Witness, Not Merely the Result

Our original program had always returned the correct result. A conventional assertion could therefore pass before and after the fix.

“How do we prevent the line from disappearing again?” I asked.

“Ask the witness whose testimony was wrong.”

The regression tests enabled <code class="language-ruby">TracePoint.new(:line)</code> and asserted that the loop-condition event appeared before the body event. One used the minimal <code class="language-ruby">while true</code> example; another used the realistic <code class="language-ruby">while chunk = super</code> predicate.

“So the test does not merely prove what the program computes,” I said. “It proves what Ruby promises tools they can observe.”

“Exactly. Instrumented runtimes have more than one audience.”

Two executions may return the same value yet differ in debugger steps, coverage, trace events, stack metadata, or profiling samples. When those observations form a supported API, result-only testing cannot establish correctness.

## Epilogue: The Meaning of Equivalent

“I called the optimized routes equivalent because they reached the same destination,” I reflected.

“For the executing program, they did,” Holmes said. “For the observer, one route omitted a promised landmark.”

Compiler transformations are usually expected to preserve program meaning. Runtimes with debugging and instrumentation APIs have a wider meaning to preserve: not every internal step, but every event their contracts make observable.

Holmes marked line two in the trace and returned the pencil to his desk.

“The program always knew it had been there, Watson. We merely persuaded it to leave a record.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
