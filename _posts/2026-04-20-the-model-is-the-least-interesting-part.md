---
layout: post
title: "The Model Is the Least Interesting Part"
description: "Swapping models rarely fixes broken systems. The scaffolding is the product."
date: 2026-04-20
tags: [craft, contrarian]
---

Every few months a new model drops and the same conversation repeats across every team building agents. Should we switch? Will it fix our problems? The demo of the new model looks incredible. Meanwhile the system around the model, the evals, the tools, the context pipeline, the error handling, sits untouched, quietly being the actual reason things do or do not work.

Here is the contrarian thesis, stated plainly: the model is the least interesting part of your system. Not unimportant, least interesting. Interesting, in engineering, means "where the leverage is." And the leverage is almost entirely in the scaffolding.

## The swap test

Here is a diagnostic I run on struggling agent projects. I ask: if we swapped in a model twice as capable tomorrow, with zero other changes, would our biggest problems go away?

The answer is almost always no. The biggest problems are: the eval set does not reflect production, the tools return garbage the agent cannot detect, the context is bloated with irrelevant retrieval, failures are silent, nobody owns the 2am page. A smarter model does not fix any of these. It produces more articulate wrong answers, faster, at higher cost per token.

Flip it around: a well-built system survives model swaps. Clean tool contracts, validated inputs and outputs, a golden set that gates changes, observability at every step, these do not care which model sits in the middle. When a better model appears, you run the evals, confirm the improvement, and switch. The system absorbs it. That is what good architecture feels like: the interchangeable part is interchangeable.

If swapping models feels scary, the model is not your problem. The scaffolding is.

## "Waiting for the next model" is procrastination

The most expensive sentence in AI engineering is "let us wait for the next model." It sounds prudent. It is usually procrastination wearing a strategy costume.

The logic seems sound: models are improving fast, so problems that are hard today will be easy in six months, so why invest in scaffolding? Because the problems that the next model solves are not your problems. The next model will be better at reasoning, at following instructions, at using tools. It will not write your eval set, design your tool contracts, instrument your traces, or define your ownership model. Every one of those is still yours, and every month you wait is a month your system stays broken in ways no model release will fix.

There is a sharper version of this. Teams that wait for the next model are implicitly betting that their problems are capability problems. But most production agent problems are systems problems: reliability, observability, cost, trust. Capabilities improve on a curve. Systems improve only when someone does the work. No release notes will ever contain "fixed your missing eval suite."

Ship with today's model. Build the scaffolding as if the model will never improve, because the scaffolding is the durable part of what you are building.

## Design for the thin model interface

Model-agnostic design is a concrete practice, not a slogan. It means the system interacts with the model through a narrow, well-defined interface: send context, get a structured response, handle the failure modes. Everything model-specific lives behind that boundary.

In practice this means:

**Capability probing, not name recognition.** Do not branch your logic on model names ("if GPT-X do this, if Claude-Y do that"). Probe capabilities: can this model handle this context length, does it follow this output schema reliably, does it need few-shot examples for this task. Names change monthly. Capabilities are what you actually depend on.

**Structured outputs as the contract.** The boundary between your system and the model should be schemas, not prose. If the model returns JSON against a schema, swapping models is a config change. If your code parses the model's free text with regexes tuned to one model's habits, swapping models is a rewrite. Every regex is a coupling.

**Version the model like any dependency.** Pin the model identifier in config, run evals on change, roll back when a new version regresses. Models are dependencies with unusually frequent breaking changes. Treat them with the suspicion dependencies deserve.

## Where model choice actually matters

Intellectual honesty requires the other side. Model choice does matter, in narrow places:

**Capability cliffs.** Some tasks sit exactly on a capability boundary: the weaker model fails reliably, the stronger one succeeds reliably. If your core task lives on a cliff, model choice is load-bearing. But notice what this means: you have a single point of failure with no redundancy. The robust move is usually to redesign the task so it does not sit on a cliff, not to pay rent on the bigger model forever.

**Cost at scale.** When the system works, the per-task cost difference between models becomes the dominant economic question. This is a real decision, but it comes after the system works, not before.

**Specific modalities and languages.** Some models genuinely lead in specific areas: a particular language, code, long context, tool use. If your product lives in one of these niches, choose accordingly. This is the exception that proves the rule: it matters where the task touches a real capability gap, not as a general strategy.

## The migration playbook

Saying "the system should survive model swaps" is easy. Doing a swap safely is a procedure, and most teams improvise it. Here is the boring version that works:

**Shadow mode first.** Run the new model alongside the old one on production traffic, without serving its outputs. Compare: agreement rate, eval scores on the shadow outputs, cost and latency deltas. Shadow mode catches the surprises, and there are always surprises: the new model that is better on benchmarks but worse on your specific task shape, the one that is faster but sloppier with tool schemas.

**Canary on a slice.** Route a small percentage of real traffic to the new model. Watch the metrics that matter: task success from your evals running on sampled production traffic, error rates, user correction rates, cost per task. Not vibes, numbers.

**Eval-gated rollout.** The full switch happens when the canary data clears the bar you set in advance. And "in advance" is doing heavy lifting in that sentence: decide the promotion criteria before the canary starts, or you will rationalize whatever the data says.

**Keep the rollback ready.** The old model config stays one revert away until the new one has proven itself over a meaningful window. Model versions get deprecated and pulled; have a fallback that is not "scramble."

Notice what makes this possible: the thin model interface, the eval suite, the observability. The migration playbook is just the scaffolding doing its job. Teams without the scaffolding cannot run this playbook, which is why their model swaps are leaps of faith.

## Invest in what persists

Models turn over in months. What persists across generations: your eval set, your tool contracts, your observability, your understanding of your users' real tasks, your team's operational discipline. These compound. A team with great evals and a mediocre model beats a team with a great model and no evals, and the gap widens with every model generation, because the first team absorbs each new model in a week while the second team restarts the same arguments.

So the next time the conversation turns to which model, redirect it. Ask what the evals say. Ask what the traces show. Ask which tool is failing. The model is the least interesting part of your system, which is good news: it means the interesting parts are the ones you control.

When did a model swap last fix a real problem of yours, versus when did scaffolding work fix it?
