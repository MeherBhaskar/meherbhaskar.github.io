---
layout: post
title: "Latency Is a Feature"
description: "Latency shapes user trust and behavior as much as answer quality. Budget it per step like you budget cost."
date: 2025-05-19
tags: [production, latency]
---

Nobody ever praised an agent for being thorough but slow. Users do not experience your system's reasoning quality and its latency as separate attributes. They experience one thing: how it felt to use. And slow feels broken, no matter how good the answer is.

Latency is treated as an ops concern, something to optimize after the real work of capability is done. That ordering is backwards. Latency is a feature. It shapes trust, behavior, and whether anyone uses the thing twice.

## Slow gets abandoned

Watch what users actually do with a slow agent. They do not wait patiently and admire the thoroughness. They rephrase and resubmit, which queues a second run. They open a new session, losing all context. They switch to the faster competitor, or back to doing it manually. Every one of these behaviors looks, in your metrics, like something other than what it is: a latency casualty disguised as a user error, a context problem, or churn.

The cruel part is that latency damage is invisible in offline evals. Your golden set scores the final answer. It does not score the forty-five seconds the user waited, the tab they switched to, the attention they lost. You can have a 95 percent task success rate and a product nobody uses, because success measured without time is not success as experienced.

There is also a trust dynamic. Fast responses signal competence. When a system answers quickly, users extend it the benefit of the doubt on small imperfections. When it is slow, users scrutinize: the wait raised the stakes, and now the answer had better be worth it. Latency does not just cost time, it raises the bar for everything else.

## Budget latency per step

The fix starts with treating latency like cost: a number you design against, decomposed per step. Define a latency budget for the whole task, then allocate it across steps the way you would allocate a financial budget. The retrieval step gets 800 milliseconds. The reasoning step gets 3 seconds. The tool calls get 2 seconds each.

This does two things. First, it makes trade-offs explicit. If the reasoning step wants 8 seconds, something else has to give, or the budget has to grow with a conscious decision. Second, it tells you where to aim. Aggregate latency numbers hide the truth; per-step budgets name the offender.

Measure distributions, not averages. The average latency of your agent is a fiction nobody experiences. Users experience the tail. If your p50 is 4 seconds and your p99 is 40 seconds, you do not have a 4-second product. You have a product that is occasionally unusable, and "occasionally" at scale means constantly, for someone. Alert on the p99. Optimize the p99. The average will take care of itself.

## Parallelize what is independent

Agent chains are usually drawn as sequences, and usually built as sequences, even when the steps do not depend on each other. Three independent tool calls run one after another, each paying full latency, when they could run together and cost the max instead of the sum.

This is the cheapest latency win in most systems, and it is pure architecture: look at your chain, find the steps with no data dependency between them, and run them concurrently. The orchestrator pattern helps here, since fan-out is its native shape. Chains compound errors and add latencies; fan-out contains errors and takes the max.

Be honest about what is truly independent, though. Steps that look independent often share a hidden dependency through the context: step B does not need step A's output, but both need the same retrieved documents, so you can fetch once and share. Design the data flow, not just the control flow.

## The hidden latency taxes

Beyond the visible chain, agent systems pay latency taxes that never appear in any single step's budget.

**Cold starts.** The first call in a session pays for everything: connection setup, model loading, cache warmup. Users disproportionately experience the first interaction, which is disproportionately slow. Warm what you can, and do not let the cold start define the first impression.

**Retry storms.** A flaky tool with a naive retry policy turns one slow call into three slow calls. Worse, retries in agents often re-run the model reasoning that led to the call, so the cost is not just the tool latency multiplied, it is the whole step multiplied. Retry with backoff, cap the attempts, and circuit-break tools that are clearly down instead of hammering them.

**Context re-reads.** Every step that sees the full conversation history re-pays the cost of reading it. As the history grows, every step gets slower, which means latency degrades over the course of a session, exactly when the user is most invested. Summarize aggressively, keep working state compact, and question whether step twelve really needs to re-read steps one through eleven.

**Sequential thinking that could be parallel.** Model reasoning is often structured as one long chain of thought when parts of it are independent. If the agent needs to analyze three aspects of a document, those analyses can run as parallel sub-calls rather than one serialized deliberation. The total tokens are similar; the wall-clock time is not.

Find these taxes by looking at a real trace and asking of every gap between spans: what was happening here, and did it need to happen serially? The answers are usually embarrassing, which is why the exercise is valuable.

## Stream, and show work early

Not all latency can be engineered away. Some tasks just take time. For those, the psychology of waiting matters as much as the clock.

A blank screen for thirty seconds feels like abandonment. A stream of partial results for thirty seconds feels like progress. The elapsed time is identical; the experienced time is not. Stream everything you can: tokens as they generate, tool calls as they happen, intermediate results as they complete.

Even better, front-load value. If your agent's plan has five steps and step one already produces something useful, show it. A user who sees a useful partial result in three seconds will wait twenty more for the rest. A user who sees nothing for twenty seconds has already left. Design the output order, not just the output.

Progress indicators help, but only if they are honest. A spinner that spins for an unknown duration is barely better than nothing. A checklist of steps with the current one highlighted, "Searching sources... Analyzing... Drafting...", gives the user a model of what is happening and how much remains. People tolerate waits they understand. They do not tolerate voids.

## The latency-quality frontier

Here is the honest trade-off: latency and quality are on a frontier, and every system sits somewhere on it. More reasoning steps, bigger models, more retrieval, all cost time. The question is never "how do we get both," it is "where on the frontier should we sit for this task."

Different tasks want different points. A code review agent can take a minute; the user is doing something else anyway. A conversational assistant cannot. A background research agent can take ten minutes; nobody is watching. The mistake is one latency target for every task. Route by urgency the way you route by difficulty: fast paths for interactive use, slow paths for background work, and make the choice visible so users know what to expect.

And revisit the frontier regularly. Models get faster, techniques improve, your own system gets tighter. A latency budget set a year ago is probably wrong today. But have a budget, per step, measured at the tail, or you are not managing latency at all. You are just hoping.

What is your p99, and when did you last look at it?
