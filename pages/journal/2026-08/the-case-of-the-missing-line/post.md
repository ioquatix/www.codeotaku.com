# The Case of the Missing Line: A Ruby Mystery

*Being an account of a line of Ruby which certainly executed but left no trace of having done so, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Impossible Trace

The program contained three executable lines:

```ruby
raise if 1 == 2
while true
  break
end
```

The first condition was false. The loop condition was true. The body executed and broke from the loop. Yet <code class="language-ruby">TracePoint.new(:line)</code> reported only lines one and three:

```ruby
[1, 3]
```

Line two had plainly participated in the program's control flow, but Ruby emitted no line event for it. [Bug #22218](https://bugs.ruby-lang.org/issues/22218) reproduced the same behavior on Ruby 3.3, 3.4, and 4.0.

“A missing event is not necessarily a missing execution,” I ventured.

“No,” Holmes replied, “but a tracing API exists to make that distinction observable. If the line executed and the trace omitted it, our account of the program is incomplete.”

## Chapter II: What a Line Event Means

<code class="language-ruby">TracePoint</code> lets debuggers, tracers, profilers, and diagnostic tools observe events inside Ruby execution. A <code class="language-ruby">:line</code> event does not mean that every expression has its own callback. It marks the source lines which Ruby's compiled instruction sequence identifies as execution points.

That mapping is part of the language tooling contract. Developers use it to step through methods, explain which branches ran, and associate runtime behavior with source. Coverage uses closely related information, but ordinary <code class="language-ruby">TracePoint</code> consumers do not necessarily enable coverage.

The missing line also appeared in less artificial code:

```ruby
def read
  return if @finished

  while chunk = super
    consume(chunk)
  end
end
```

Here the loop condition performs real work by calling <code class="language-ruby">super</code> and assigning its result. Omitting its line event can make a trace suggest that execution jumped from the guard directly into the loop body.

## Chapter III: Following the Bytecode

CRuby compiles Ruby source into YARV instructions. It also attaches event flags to selected instructions so the interpreter knows when to notify <code class="language-ruby">TracePoint</code> and Coverage.

The loop shape introduced an intermediate jump carrying the line-two event. A peephole optimization then noticed that one branch led to a jump which led somewhere else. It shortened the route by retargeting the first branch directly to the final destination.

In simplified form, the compiler changed this:

```text
branch unless condition -> jump_with_line_event
jump_with_line_event    -> loop body
```

into this:

```text
branch unless condition -> loop body
```

The optimized program produced the same Ruby result, but execution no longer visited the instruction carrying the line event.

“The line was not removed from the source,” I said. “Only the road sign which announced it.”

“And to a traveller concerned solely with the destination, the shorter road is equivalent,” Holmes replied. “To an observer mapping the journey, it is not.”

## Chapter IV: An Old Clue with a Narrow Remedy

This control-flow shape was not entirely new. [Bug #15980](https://bugs.ruby-lang.org/issues/15980) had found that the same jump optimization could make line coverage inaccurate. Ruby already avoided the optimization when line coverage was enabled and the skipped instruction carried event metadata.

That safeguard was deliberately tied to coverage. The compiler source even noted the remaining limitation: ordinary <code class="language-ruby">TracePoint</code> line events could still miss the loop condition.

The prior state explained the apparent inconsistency. Coverage and TracePoint consumed related event flags, but enabling coverage activated an optimization guard which a standalone TracePoint did not receive. The same source could therefore look complete to Coverage and incomplete to another tracing tool.

## Chapter V: Preserve the Evidence

An [earlier proposal](https://github.com/ruby/ruby/pull/17825) explored representing the control-flow edge more explicitly. Discussion led to a smaller solution: retain the existing event-bearing jump whenever removing it would erase a line event.

[The merged fix](https://github.com/ruby/ruby/pull/18122) changed the peephole condition to stop this particular retargeting when the intermediate instruction carries either <code class="language-c">RUBY_EVENT_LINE</code> or <code class="language-c">RUBY_EVENT_COVERAGE_LINE</code>:

```c
int stop_optimization =
    nobj->link.type == ISEQ_ELEMENT_INSN &&
    (nobj->insn_info.events &
        (RUBY_EVENT_LINE | RUBY_EVENT_COVERAGE_LINE));
```

Other jump-to-jump folding remains available. The compiler preserves only the instruction whose removal would change what Ruby's instrumentation can observe.

With that route restored, the original program reports the expected sequence:

```ruby
[1, 2, 3]
```

## Chapter VI: Correctness Has a Dispatch Cost

Keeping the intermediate jump means the interpreter may dispatch one additional YARV instruction on an affected edge. It would have been easy either to dismiss that cost as trivial or to preserve the optimization and declare tracing exceptional. Neither answer measures the actual tradeoff.

Targeted benchmarks deliberately concentrated the affected pattern. The interpreter slowed by about one percent in a hot loop and 2.7 percent in a minimal guarded reader. Those are upper-bound cases where nearly every iteration or call traverses the retained jump, not estimates for general Ruby programs.

YJIT and ZJIT recovered the control-flow optimization at a different layer. YJIT can place the target block next and emit no machine jump; ZJIT cleans the redundant chain from its control-flow graph. The same reader benchmark showed no repeatable JIT regression.

This division is useful. The bytecode remains semantically complete for interpreters and instrumentation. A JIT, which can preserve the necessary event behavior while reorganizing machine control flow, remains free to optimize the extra jump away.

## Chapter VII: Testing What Tools Can See

The regression tests did more than assert the program's return value, which had never been wrong. They enabled <code class="language-ruby">TracePoint.new(:line)</code> and verified that the loop-condition event appeared before the body event.

One test used the minimal <code class="language-ruby">while true</code> case. Another used the realistic <code class="language-ruby">while chunk = super</code> predicate. Together they protected both the reduced compiler shape and the behavior which matters to tracing tools.

That is an important testing lesson for instrumented runtimes. Two executions may compute the same result yet differ in debugger steps, coverage, trace events, stack metadata, or profiling samples. If those observations are part of a supported API, result-only tests cannot establish correctness.

## Epilogue: Optimization Must Preserve Observation

Compiler optimizations are usually described in terms of program meaning: transform the implementation without changing its result. A runtime with debugging and instrumentation APIs has a wider definition of meaning. It must also preserve the events it promises observers.

The missing line was never a parser error, nor a failure to run the loop condition. It was evidence discarded by a control-flow shortcut.

Holmes marked line two in the trace and returned the pencil to his desk.

“The program always knew it had been there, Watson. We merely persuaded it to leave a record.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
