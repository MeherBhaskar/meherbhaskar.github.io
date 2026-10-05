---
layout: post
title: "You Cannot Debug What You Cannot See"
description: "Agent failures are mysteries because agent internals are invisible. Observability for agents means treating every run like a distributed trace."
date: 2026-06-15
tags: [observability, production, multi-agent]
---

When a traditional service fails, you have a playbook: check the logs, look at the metrics, pull the trace, find the slow span, read the exception. When an agent fails, most teams have nothing. A user reports a bad output, someone stares at it, someone guesses. The failure is a mystery because the internals were never instrumented.

This is the observability gap, and it is the reason agent incidents take ten times longer to resolve than they should. You cannot debug what you cannot see.

## Every run is a trace

The mental model that fixes this: an agent run is a distributed trace. Each step, each model call, each tool invocation, each handoff between agents, is a span. The spans nest. The trace tells the story of what happened, in order, with timings and inputs and outputs.

Most agent frameworks can emit this, and most teams never turn it on. Then the incident comes, and there is no record of what the agent saw or did, only the final output sitting there like a punchline without the joke.

Instrument from the start. Log at every step: the full prompt context (or a reference to it), the model and parameters, the raw output, every tool call with its arguments and results, timings for each span, and the final answer. This is not overhead, it is the difference between debugging and divination.

Yes, this is a lot of data. Sample aggressively in steady state and keep full traces for failures, slow runs, and a random fraction of successes. The traces you need most are the ones from the runs that went wrong, so make sure those are always captured in full.

## Log the raw, not the summarized

A common mistake: logging summaries of what happened instead of what actually happened. "Agent called the search tool" is a summary. The actual tool arguments, the raw response, the parsed result, that is the data.

Summaries embed someone's theory of what matters. Raw data lets you form your own theory during the incident, which is exactly when the original theory is most likely wrong. Disk is cheap. Regret is expensive.

The same applies to model interactions. Log the full context the model saw, not just your summary of the task. When the output is bizarre, the explanation is almost always in the context: a retrieved document that said something unexpected, a tool result that was misparsed three steps ago, an instruction that conflicted with another. You will never find it from the summary.

## Replay: the superpower

Once you have full traces, you get the superpower: replay. Take a failed run, reconstruct the exact inputs at any step, and re-execute from there. Change the prompt, swap the model, fix the tool response, and see what happens.

Replay turns incidents into experiments. Instead of theorizing about what went wrong, you test it. Instead of shipping a fix and hoping, you validate the fix against the exact failure before it goes out. Every mature engineering discipline has this: record, replay, verify. Agents are just late to it.

To make replay work, your steps need to be deterministic given their inputs, or at least re-executable. Log the inputs completely enough that re-execution is faithful. This is another reason raw data beats summaries.

## Metrics that matter

Beyond traces, a few metrics earn their dashboard:

**Task success rate**, scored by your evals running on sampled production traffic, not by vibes. This is the top-line health metric.

**Cost and latency per task**, with distributions, not just averages. The p99 tells you about your worst users.

**Tool failure rate**, per tool. Your agent is only as reliable as its worst tool, and this metric names it.

**Escalation and fallback rate.** How often does the system hit its guardrails? A rising rate means the world changed or the system degraded.

**User correction rate.** How often do users retry, rephrase, or undo? This is the metric closest to actual user pain.

## Operate it like a service

Here is the reframe: an agent in production is a service, and it deserves service-grade operations. Traces, metrics, logs, alerts, runbooks, incident reviews. The fact that the internals are probabilistic does not exempt you from any of this, it makes all of it more necessary.

The teams that do this resolve incidents in minutes and improve weekly, because every failure becomes data. The teams that do not resolve incidents in days and improve never, because every failure becomes folklore.

Stop flying blind. Instrument the run, log the raw, build replay, watch the metrics. The next incident is coming either way. The only question is whether you will be able to see it.

What does your agent observability stack look like today?
