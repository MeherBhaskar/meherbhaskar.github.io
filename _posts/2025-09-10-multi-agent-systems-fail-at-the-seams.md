---
layout: post
title: "Multi-Agent Systems Fail at the Seams"
description: "Individual agents work fine. The failures live in the handoffs: context loss, schema drift, and error compounding between agents."
date: 2025-09-10
tags: [multi-agent, orchestration, production]
---

Test each agent in a multi-agent system in isolation and most of them work. Put them together and the system falls over. The failures are rarely inside any single agent. They live at the seams, in the handoffs between agents, and that is exactly where nobody is looking.

This is the same lesson distributed systems learned decades ago: components are easy, interactions are hard. We are relearning it with agents, one painful incident at a time.

## Context loss at handoffs

Agent A does careful work: it reads the request, gathers context, reasons through the problem, and produces a result. Then it hands a two-sentence summary to Agent B, and half the understanding evaporates.

Every handoff is a compression step, and compression is lossy. The question is never whether information is lost but whether the lost information mattered. It usually did. Agent B then operates on a thin summary, makes confident decisions on incomplete understanding, and passes its own thin summary to Agent C. By the third hop, the system is running on vibes.

The fix is to be deliberate about what crosses each boundary. Pass structured state, not prose summaries. Define exactly what the downstream agent needs and verify it receives it. When the handoff must be prose, include the reasoning, not just the conclusion: Agent B needs to know why Agent A decided what it did, because the why determines what to do when the situation does not match the summary.

Better yet, question whether the handoff needs to exist. Every seam is a failure surface. Some multi-agent designs are really single-agent designs with extra steps.

## Schema drift between agents

Agent A outputs JSON. Agent B expects JSON. In the demo, the fields match. In production, Agent A starts emitting a slightly different shape, a renamed field, an extra nesting level, a null where a string used to be, and Agent B silently misparses it or crashes.

This is an API contract problem, and it deserves API contract treatment: schemas defined once, shared between agents, validated at every boundary. When Agent A's output does not validate against the contract, the failure should be loud and immediate, not a quiet corruption that surfaces three agents later as a bizarre decision nobody can explain.

The insidious version is semantic drift without syntactic drift. The fields still validate, but their meaning has shifted: a "priority" field that used to mean urgency now means something closer to order of arrival, because the upstream agent's behavior changed subtly. Schemas cannot catch this. Only evals on the handoffs can, which is why you should test the seams, not just the components.

## Error compounding

A single agent that is right 90 percent of the time sounds good. Chain five of them and, if errors were independent, you would be right 59 percent of the time. Errors are not independent, they are worse than independent: an early agent's mistake becomes a later agent's premise, and later agents reason confidently from false premises. The system does not just err, it err with conviction.

This is why verification placement matters more than agent cleverness. Put checks at the seams: validate outputs against contracts, have a critic agent review high-stakes handoffs, and design the chain so that uncertainty propagates instead of being rounded off to false confidence. An agent that says "I am unsure about X" is worth three that guess.

Also consider the topology. Long chains compound errors multiplicatively. Fan-out with aggregation contains them: if five agents independently assess something and you take the consensus, one bad agent is outvoted. The orchestrator pattern, one coordinator with many workers, exists for this reason. It is not just an org chart aesthetic, it is error arithmetic.

## Debugging across the seams

When a multi-agent system misbehaves, the instinct is to look at the final output and guess. Do not. You need traces: the full sequence of handoffs, what each agent saw, what it decided, what it passed on. Log the inputs and outputs at every seam, with the schemas, so you can replay any handoff in isolation.

The question to ask of every incident is always the same: which seam failed? Was the information lost in compression, was the contract violated, or did an error compound through the chain? The answer tells you which fix to apply, and the fixes are different: richer handoff state, stricter contracts, or verification at the boundary.

Build the seams first and the agents second. The agents are the easy part. Everyone tests the agents. Almost nobody tests what happens between them, and that is where your system actually lives or dies.

What is the worst seam failure you have debugged?
