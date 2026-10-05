---
layout: post
title: "The Fallback Ladder"
description: "Every capability needs degraded modes. Design the ladder before you need it, not during the incident."
date: 2025-08-18
tags: [production, reliability]
---

Every agent I have seen in production has a happy path that works beautifully and a failure mode that nobody designed. The model call times out. The tool returns garbage. The retrieval index is stale. And the system does the only thing it was never taught not to do: it fails completely, confidently, and at 2am.

Reliability does not come from hoping the happy path holds. It comes from designed degradation. Every capability in your system should have a ladder beneath it: a series of cheaper, simpler, dumber fallbacks, each one ready to catch the failure of the rung above. You design the ladder before you need it, because during the incident is too late.

## The anatomy of a ladder

A fallback ladder is an ordered list of degraded modes for a single capability, from best to worst, where "worst" is still better than a total failure. Consider a product recommendation agent. The ladder might look like this:

**Rung 1: Full agent.** The flagship model reasons over fresh retrieval, calls the inventory tool, personalizes the ranking. Best quality, highest cost.

**Rung 2: Simpler model, same pipeline.** A smaller model runs the same steps. Slightly worse reasoning, a fraction of the cost, and often surprisingly close on routine requests.

**Rung 3: Cached or precomputed answer.** For common requests, serve the last good answer. Stale is better than broken, and for slowly changing data it is barely worse than fresh.

**Rung 4: Heuristic.** A rules-based fallback: bestsellers in the category, no personalization, no reasoning. Dumb, fast, nearly free, and never hallucinates.

**Rung 5: Honest refusal.** "I can't do this right now." This is the bottom rung and it is a feature. A clean admission beats a confident fabrication every time.

Most systems ship with rung 1 and nothing else. The distance from rung 1 to a total outage is exactly one failure. The ladder turns that cliff into stairs.

## Deciding the triggers

A ladder without triggers is decoration. For each rung, define exactly what causes the step down: a timeout, an error rate threshold, a validation failure, a latency budget exceeded. These triggers should be boring and mechanical, not model-judged. You do not want the system deciding whether it is confused. You want a timer and a schema check.

Two principles matter here. First, triggers must be on signals you actually measure: timeouts, HTTP statuses, schema validation results, cost counters. If you cannot observe it, you cannot trigger on it. Second, stepping down should be sticky for a cooldown period. A system that flaps between rungs on every other request is harder to debug than one that degrades cleanly and recovers deliberately.

Also decide, in advance, what stepping down means for the user. Silent degradation is sometimes right (a slightly worse recommendation nobody notices) and sometimes wrong (a financial calculation done by heuristic). The user-facing contract of each rung is a product decision, not an engineering detail. Make it deliberately.

## Test the ladder with fault injection

Here is the uncomfortable truth: most fallback code has never run. It was written, reviewed, merged, and then sat there while the happy path handled 100 percent of traffic. The first time it executes is during a real incident, which is the worst possible moment to discover it is broken.

Fault injection fixes this. Deliberately break things in staging, or in production during low-traffic windows with careful blast radius control: kill the model endpoint and watch the system step down to rung 2. Corrupt the tool response and watch validation catch it. Expire the cache and watch the heuristic take over. If any rung fails to catch, you found the bug on your terms, not the incident's.

Make this a regular practice, not a one-time exercise. Ladders rot. The cached fallback starts serving data in a format the new frontend cannot parse. The heuristic references a category taxonomy that was renamed. The "honest refusal" message promises a retry that no longer exists. Run the fault drills on a schedule, the same way you would run any other test suite, because that is what they are.

## Partial degradation in chains

So far I have described the ladder for a single capability. Real systems are chains, and chains raise a harder question: when one step degrades, what happens to the rest?

The naive answer is that the whole chain steps down together. The better answer is per-step ladders with a propagation policy. If the retrieval step falls back to cached results, the reasoning step can still run at full capability, because slightly stale context rarely breaks reasoning. But if the reasoning step falls back to a smaller model, the verification step should get stricter, not looser, because the error rate upstream just went up.

This is the design insight most teams miss: degradation should be compensated, not just accepted. Every step down the ladder somewhere should trigger a corresponding tightening somewhere else. Weaker reasoning gets stronger validation. Staler data gets fresher checks. Cheaper models get more careful prompts. The ladder is not just a set of degraded modes, it is a set of rebalanced configurations.

The way to find these configurations is the same fault injection from before, but at the chain level. Break one step and watch what the downstream steps do with the degraded input. If the answer is "they confidently produce garbage," your chain has no compensation logic, and that is the actual bug.

## The discipline: no capability without its degraded mode

The real thesis is a process rule, not an architecture pattern: never ship a capability without its ladder. When someone proposes a new agent feature, the design review asks two questions. What does the happy path do? And what happens at each rung when it does not?

This feels slow. It is slower than shipping the happy path alone. But compare it to the alternative: the incident where the flagship model had an outage and your entire product went dark for three hours, because nobody designed rung 2. The ladder is not overhead. It is the product, for every user who arrives during the failure, which over a long enough timeline is every user.

There is a second-order benefit too. Designing the ladder forces you to understand your capability's actual requirements. When you ask "what is the dumbest version of this that is still useful," you often discover the smart version was overbuilt. Teams that design ladders regularly find themselves shipping rung 3 as the default and keeping rung 1 for the hard cases, which is cheaper, faster, and more reliable all at once.

Start with your most critical capability. Write down the five rungs. Define the triggers. Break it on purpose. Then do the next one. Reliability is not a property you add at the end. It is a ladder you build underneath, one rung at a time, before you need it.

What is the capability in your system with the longest fall to the ground?
