---
layout: post
title: "Fan-Out Beats Chains"
description: "Long agent chains compound errors multiplicatively. Parallel assessment with aggregation contains them."
date: 2026-03-16
tags: [multi-agent, orchestration]
---

I have written before about multi-agent systems failing at the seams, in the handoffs between agents. This post is about the deeper structural question underneath: given a task, should your agents work in a chain or in parallel? The answer matters more than almost any other architectural choice, because topology is error arithmetic. Chains multiply failure probabilities. Fan-out with aggregation suppresses them.

## The math nobody does

Take a chain of five agents, each correct 90 percent of the time on its step. If errors were independent, the chain is correct 0.9^5, about 59 percent of the time. In practice it is worse, because errors are not independent: an early agent's mistake becomes a later agent's premise, and later agents do not just inherit the error, they build confidently on top of it. A wrong retrieval result does not merely pass through the reasoning step, it gets woven into a coherent-sounding wrong answer.

Now take the same five agents running in parallel on the same task, with their outputs aggregated by voting or a judge. If each is right 90 percent of the time independently, the majority is wrong only when three or more agents err simultaneously, which happens roughly 1 percent of the time. Same agents, same task, radically different reliability. The difference is entirely topology.

This is not a new insight. It is the reason distributed systems replicate: independent failures do not compound when you vote. We keep rediscovering it because chains feel natural. They mirror how a person would do the task step by step, and anthropomorphic design is a trap. The machine does not think like you, and architectures that flatter human intuition are not architectures optimized for machine reliability.

## When chains are still right

Chains are not always wrong. Some tasks have strictly sequential dependencies: step two cannot begin until step one produces its output, because the output determines what step two even is. Planning then execution. Retrieval then synthesis over what was retrieved. These are genuinely chains, and no amount of fan-out removes the dependency.

The discipline is to distinguish real dependencies from habitual ones. Most chains I review contain steps that look sequential but are not: three independent research subtasks run in sequence because someone wrote them as a list, when they could run in parallel and merge. Audit your chains for false sequentiality. Every dependency you can dissolve is error multiplication you can delete.

When the dependency is real, shorten the chain anyway. Ask of each step: does this earn its place? A five-step chain where two steps add marginal value is a three-step chain with decoration, and the decoration is taxed at the error rate of every step it touches.

## Aggregation strategies

Fan-out is only half the design. The other half is how you combine the parallel outputs, and the choice shapes the system's character:

**Voting** works when outputs are discrete and comparable: classifications, yes-or-no judgments, selections from a fixed set. Simple, robust, and easy to reason about. Its weakness is ties and its blindness to confidence: a 3-2 vote where the two dissenters are the most capable agents should give you pause.

**Judge aggregation** uses another model (or a rules engine) to pick the best output or synthesize across them. More flexible than voting, handles free-form outputs, but now the judge is a single point of failure and a new thing to evaluate. Do not let the judge be dumber than the workers it judges.

**Synthesis** merges the parallel outputs into one: take the best parts of each. Powerful for research-style tasks where different agents surface different facts. Risky when outputs conflict, because the synthesizer must resolve contradictions, which is itself an error-prone step. Synthesis works best when the workers produce structured, comparable outputs rather than prose.

**Confidence-weighted combination** asks each agent how sure it is and weights accordingly. Elegant in theory, fragile in practice, because model-reported confidence is poorly calibrated. If you go this route, calibrate on real data first, and be skeptical of what you find.

The meta-principle: the aggregator is part of the system and needs its own evals. Teams carefully evaluate their workers and then bolt on an unexamined judge. Evaluate the whole topology end to end.

## The orchestrator as error containment

This is why the orchestrator pattern dominates serious multi-agent systems: one coordinator, many workers, aggregation at the center. It is not just an org chart aesthetic. It is error containment by construction.

The orchestrator can retry failed workers without redoing the whole task. It can detect disagreement between workers and escalate only the contested cases. It can apply different aggregation strategies per subtask. And crucially, one bad worker cannot poison the rest, because workers never talk to each other directly. The seams that kill chained systems barely exist: every handoff goes through the orchestrator, which validates, normalizes, and decides.

The orchestrator is also where verification lives. Contract checks on worker outputs, plausibility screens, escalation policies, all in one place, all testable. In a chain, verification is smeared across every link or absent entirely. In an orchestrated fan-out, it has an address.

## The cost objection, answered

Fan-out costs more per task: five agents instead of one chain of five steps is roughly comparable in tokens, actually, but parallel workers with a judge on top does add overhead. The objection is real but usually mispriced. What costs more: the extra tokens, or the wrong answers? For high-stakes tasks, the error rate dominates the economics completely. For low-stakes tasks, you probably do not need five agents at all, you need one good one.

There is also a latency subtlety people get backwards. Chains are slow because steps are sequential: five steps at ten seconds each is fifty seconds. Fan-out runs the workers in parallel: five workers at ten seconds each plus aggregation is barely over ten seconds. Parallelism buys reliability and latency at the price of tokens. For interactive products, that trade is almost always worth making.

## Mixed topologies in practice

Real systems are rarely pure chains or pure fan-out. They are hybrids, and the skill is knowing which part gets which topology. Consider a research agent: the gathering phase fans out, five workers independently searching different angles in parallel, because gathering has no sequential dependencies and benefits from coverage. The synthesis phase is a short chain: merge, verify against sources, draft. The merge depends on the gathered material, so it is genuinely sequential, but it is two steps, not twelve.

The design heuristic: fan out where tasks are independent, chain where dependencies are real, aggregate at every convergence point, and verify at every seam. Draw the dependency graph honestly. Most "pipelines" people sketch are actually graphs with far more parallelism than the drawing suggests, because drawing boxes in a row is easier than thinking about what truly depends on what.

One more practical note: topology should be configurable, not hardcoded. The orchestrator that fans out to five workers today might need three or eight tomorrow as models change and costs shift. If the topology is baked into code, every tuning is a deploy. If it is config, it is an experiment. The number of workers, the aggregation strategy, the retry policy, these are parameters to tune against evals, not architecture to carve in stone.

## Design the topology first

Here is the practical takeaway: before you write a single agent, sketch the topology and do the error arithmetic. If your design is a long chain, you are signing up for multiplicative failure, and you should know that before you build it, not after the incident review.

Default to fan-out with an orchestrator. Reserve chains for true sequential dependencies, keep them as short as honesty allows, and verify at every link. Topology is not an implementation detail. It is the reliability strategy.

Look at your current system: where are the chains, and which of their links are actually dependencies?
