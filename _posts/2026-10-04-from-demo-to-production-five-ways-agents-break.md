---
layout: post
title: "Your Agent Works in the Demo. Production Eats It."
description: "Five failure modes that kill AI agents between the demo and production, with concrete fixes for each, from running agentic AI at retail scale."
date: 2026-10-04
tags: [agentic-ai, production, evals]
---

Everyone has watched it happen. An agent aces the live demo: crisp answers, smooth tool calls, applause. Then it meets production traffic and falls apart within a week.

I've spent the last few years running agentic AI at retail scale, and I can tell you the model is rarely the problem. The scaffolding around the model is. Here are the five failure modes I see over and over, and what actually fixes each one.

## 1. Your eval set is fiction

The demo is scored on ten prompts you wrote yourself, in your own vocabulary, about the happy path. Production serves thousands of prompts written by people who type in fragments, misspell everything, and ask for things you never imagined.

If your eval set doesn't match your production prompt distribution, your eval scores are fiction.

**The fix:** stop hand-writing eval prompts. Sample real traffic. Log every prompt for a week, cluster them, and build a golden set of 50 to 200 real tasks with verified expected outcomes. Label once, reuse forever.

```python
# Build the golden set from reality, not imagination
golden = (
    production_logs
    .sample(n=200, random_state=7)   # real distribution
    .assign(expected_outcome=...)     # label once, reuse forever
)

def eval_pass_rate(agent, golden):
    return sum(agent.run(p) == e for p, e in golden) / len(golden)
```

Refresh the sample monthly. Distributions drift, and a stale golden set becomes fiction too.

## 2. Evals aren't in the deploy path

Most teams have evals. Most teams run them manually, occasionally, when someone remembers. So a prompt tweak ships on Friday, silently degrades the agent, and nobody notices until support tickets pile up Monday.

**The fix:** treat eval regressions like broken tests. Put the golden set in CI. Every prompt change, model swap, or tool update runs the eval suite, and a regression blocks the deploy. Track pass rate over time on a dashboard the whole team sees. The moment evals are optional, they're decorative.

## 3. The worst tool defines reliability

Demos use clean mock data. Production tools time out, return malformed JSON, change schemas without telling you, and rate-limit you at the worst moment. Your agent is only as reliable as its flakiest tool, and the failure mode is never a clean error. It's a confident wrong answer built on garbage tool output.

**The fix:** wrap every tool call like you don't trust it, because you shouldn't. Timeouts, retries with backoff, schema validation on outputs, and logging of raw responses so you can debug what actually happened.

```python
@retry(stop_after_attempt(3), backoff=exponential(1, 2, 4))
@timeout(seconds=20)
def call_tool(name, args):
    raw = tools[name](**args)
    return ToolSchema[name].parse(raw)  # fail loud, never weird
```

"Fail loud, never weird" is the whole philosophy. An agent that errors cleanly is debuggable. An agent that hallucinates around a broken tool is a liability.

## 4. Cost and latency compound silently

That 12-step agent chain costs $0.40 per run in the demo. Nobody blinks. At 100,000 runs a month, that's $40,000 a month, and it got there one innocent step at a time. Latency works the same way: each step adds a second, and suddenly your "real-time" assistant takes 45 seconds.

**The fix:** make cost per task a first-class metric from day one, next to accuracy and latency. Then do the unglamorous work: cache repeated tool calls aggressively, route simple tasks to smaller models, cap max steps per run, and kill chains that loop. Most production agent tasks don't need your best model. They need your cheapest adequate one.

## 5. Nobody owns the 2am page

This is the one teams forget until it bites them. When the agent does something strange at 2am, who gets paged? What dashboard do they open? Is there a kill switch, or does the agent keep running while everyone figures out whose problem it is?

**The fix:** before launch, define all three. Ownership: one team, one name, on the agent like any production service. Alerting: watch tool error rates, cost-per-task spikes, and user negative signals, not just uptime. And a kill switch: a way to halt the agent or drop it into human-in-the-loop mode for high-stakes actions, without a code deploy.

---

Agents don't fail because the model is dumb. They fail because everything around the model is unowned: the evals, the tools, the cost, the pager.

I'm going deeper on this at the OMS Analytics Conference this week. Meanwhile: which failure mode bit you hardest?
