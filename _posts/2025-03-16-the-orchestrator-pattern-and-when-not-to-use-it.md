---
layout: post
title: "The Orchestrator Pattern, and When Not to Use It"
description: "One coordinator with many workers is the default multi-agent topology for good reasons. It is still often the wrong choice."
date: 2025-03-16
tags: [multi-agent, orchestration]
---

Ask an AI engineer to draw a multi-agent system and they will draw the same picture every time: one orchestrator in the middle, a ring of specialized workers around it, arrows going in and out. It has become the default topology, the answer people reach for before they have finished asking the question.

The orchestrator pattern earned its popularity. But defaults are dangerous when they stop being decisions. Plenty of systems wearing the orchestrator shape would work better as something else, and plenty should not be multi-agent at all.

## Why the orchestrator wins

The case for it is error arithmetic. Suppose each agent is right 90 percent of the time. Chain five agents in sequence and, if errors were independent, you are right about 59 percent of the time. Errors compound through chains. That is bad.

Now fan out instead. The orchestrator sends the same task, or decomposed subtasks, to several workers and aggregates. If three workers independently assess something and you take the consensus or the best result, one bad worker is outvoted. The errors do not compound, they get contained. This is the same reason ensembles beat single models in classical ML: independent mistakes cancel, and the aggregator is a simpler, more controllable decision than a long chain of reasoning.

The orchestrator also centralizes the hard parts. State management, error handling, retries, logging, the kill switch: all of it lives in one deterministic component you can read, test, and reason about. The workers can be as probabilistic and weird as they want, because the orchestrator is the adult in the room. It validates outputs against schemas, enforces timeouts, decides what happens when a worker fails. The probabilistic parts are fenced in by a deterministic frame.

And there is a practical virtue: the orchestrator is where your observability lives. One component sees every request, every delegation, every result. When something goes wrong, you have a single trace to read instead of reconstructing a conversation from fragments.

So the pattern is good. Fan-out contains errors, the coordinator centralizes control, and debugging has a single home. These are real reasons, not fashion.

## When it is the wrong choice

Here is the uncomfortable part: a large fraction of orchestrator systems I see are solving problems that did not need multiple agents.

The test is simple. Ask what the workers know or do that one agent with tools could not. If the answer is "they each have a different system prompt," you do not have a multi-agent system. You have one agent with extra steps. Different system prompts are just different configurations, and you can get the same effect by giving a single agent good tools, good context, and a well-structured task. Every additional agent is an additional failure surface: another handoff where context gets compressed, another schema boundary that can drift, another component whose errors compound.

Multi-agent makes sense when the subtasks genuinely benefit from isolation. The classic cases:

**Parallelizable independent work.** Five documents need summarizing, or ten hypotheses need checking. The workers do not depend on each other, so fan-out buys real speed and the aggregation is simple. This is the pattern at its best.

**Genuinely different capabilities.** One worker has a code execution tool, another has web search, a third has a domain-specific model. The separation is about tools and access, not about vibes. If the capabilities could live in one agent's toolbelt without confusion, they probably should.

**Adversarial structure.** A generator and a critic, a proposer and a verifier. The value comes from the disagreement: the critic catches what the generator misses precisely because it is a separate pass with a separate objective. This only works if the critic is actually independent, with its own context and standards, not just the same agent asked nicely to double-check.

What does not justify multiple agents: "the task felt complex," "we wanted it to be modular," or "the demo looked impressive." Complexity of feeling is not a design criterion. Modularity in agent systems is achieved through tools and functions, not through agent headcount. And demos are not the product.

## The decision framework

Before adding a second agent, run through this:

1. **Can one agent with good tools do it?** If yes, stop. You are done. The orchestrator is overhead.
2. **Are the subtasks independent?** If they depend on each other in long chains, you are building error compounding, not containing it. Restructure or reconsider.
3. **Is there a real aggregation function?** Fan-out needs a meaningful way to combine results: voting, ranking, merging, selecting. If the orchestrator just concatenates worker outputs, the workers were never separate tasks.
4. **Who owns the failure?** If you cannot say what happens when worker three of five fails, times out, or returns garbage, you do not have an architecture, you have a drawing.
5. **Can you test the seams?** Each handoff needs a contract and a test. If the number of seams is growing faster than your ability to test them, the topology is too rich.

Notice what this framework does: it makes "add another agent" the expensive option, which it is. Every agent you add is a component you must instrument, test, monitor, and debug at 2am. Spend that budget where the topology earns it.

## The orchestrator's own failure modes

Even when the topology is right, the orchestrator itself is a single point of failure, and it fails in characteristic ways.

**The bottleneck.** Every decision routes through one component. If the orchestrator's reasoning is the slowest step, your parallel workers finish and wait. Keep the orchestrator's job small and deterministic: route, validate, aggregate. The moment the orchestrator starts doing deep reasoning of its own, you have rebuilt the single agent with extra steps and extra latency.

**The confused delegator.** The orchestrator must decide which worker gets what. That routing decision is itself a hard problem, and a bad router sends tasks to the wrong specialists. If your router's accuracy is the ceiling on system quality, invest in the router: give it clear worker descriptions, examples of correct routing, and evals on routing decisions specifically. Most teams eval the workers and never the dispatcher.

**Aggregation theater.** The orchestrator collects worker outputs and picks one, but the picking is where quality is made or lost. Majority vote works when workers are independent and the task has a right answer. For open-ended tasks, you need a real synthesis step with its own standards, which is itself an agent-grade problem. Do not pretend a `max()` call is judgment.

## The deeper point

The orchestrator pattern is popular partly because it mirrors how we organize people: a manager, a team, delegation. That familiarity is a trap. Human teams have shared context, hallway conversations, and the ability to ask clarifying questions cheaply. Agent handoffs have none of that. Every delegation is a compression step across a boundary with no shared understanding to fall back on.

So use the orchestrator where its strengths apply: independent parallel work, genuinely separated capabilities, adversarial verification. Everywhere else, reach for the simpler thing first: one agent, excellent tools, strict contracts, good evals. You can always add agents later, when the traces show you exactly where the single agent breaks.

The best multi-agent system is often the one you did not build. The second best is the orchestrator, used on purpose.

When did you last remove an agent from a system and watch it get better?
