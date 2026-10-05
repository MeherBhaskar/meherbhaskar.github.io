---
layout: post
title: "Agents Need State Machines, Not Vibes"
description: "Explicit states and transitions beat emergent behavior for anything that has to work twice."
date: 2025-10-20
tags: [multi-agent, orchestration]
---

There is a popular way to build agent workflows: give the model a goal, a set of tools, and instructions like "plan your approach, execute the steps, and verify the result." It works in the demo. It produces a beautiful trace where the model reasons elegantly through the task. And then in production it loops forever on step three, skips the verification step entirely, or lands in a state nobody anticipated and no one can recover from.

The problem is not the model. The problem is that we asked a probabilistic system to improvise a process. For anything that has to work twice, the process should not be improvised. It should be a state machine.

## Where emergent planning fails

Letting the model plan sounds flexible, and flexibility is the pitch. The model can adapt to unexpected situations, choose different strategies, recover from errors creatively. In practice, the failure modes are structural and repeatable.

**Loops.** The model tries an action, it fails, the model tries a slight variation, it fails, and the loop continues until the token budget or your patience runs out. There is no progress counter, no escalation, no exit. Emergent planning has no notion of "we have tried enough."

**Skipped steps.** The model decides a step is unnecessary and skips it. Sometimes it is right. Sometimes the skipped step was the validation that would have caught the error it just made. A process that can silently drop its own safety checks is not a process.

**Unrecoverable states.** The model takes an action with side effects, a booking, a write, a sent message, and then discovers the premise was wrong. There is no undo, no compensating action defined, no one thought about reversibility because the plan was being invented live.

**Untestable behavior.** If the process is improvised per run, you cannot enumerate the paths it might take, which means you cannot test them. Your eval set covers the paths you imagined. The model invents new ones in production.

None of this is an argument against models. It is an argument about where the model belongs in the architecture.

## The machine decides between, the model decides within

The state machine pattern draws a clean line: explicit states and transitions define the process, and the model operates inside bounded states. The machine decides what happens next. The model decides how to do the current step well.

Concretely, a document-processing workflow becomes states: `ingested`, `classified`, `extracted`, `validated`, `complete`, plus `needs_review` and `failed`. Transitions are guarded: you move from `extracted` to `validated` only when the extraction output passes schema validation. From `validated` you go to `complete`, or to `needs_review` if confidence is low, or back to `extracted` with feedback if validation fails, up to N retries, after which you go to `failed` and page someone.

The model is deeply involved: it does the classifying, the extracting, the confidence scoring. But it never decides the process. It cannot skip validation. It cannot loop forever, because the retry counter is in the machine, not in the model's judgment. It cannot land in an unanticipated state, because the states are enumerated.

This is less glamorous than "the agent figures it out." It is also the difference between a demo and a system.

## Guards and transitions are the contract

The most valuable part of the state machine is not the states, it is the guards on the transitions. Each guard is a precise statement of what "done" means for a step: the output validates against this schema, the confidence exceeds this threshold, the side effect is confirmed by this check.

These guards are where your evals plug in. Instead of scoring entire runs end to end and wondering which part failed, you score transitions: of all the times we attempted the `extracted` to `validated` transition, how often did the guard pass on the first try? A weak transition shows up as a number, and you know exactly where to aim the fix.

Guards also make the failure modes explicit and therefore handleable. When a guard fails after N retries, the transition to `failed` is not a crash, it is a designed outcome with an owner, an alert, and a runbook. Compare that to the emergent version, where the same situation produces an infinite loop or a silent wrong answer.

Write the guards before you write the prompts. The guards are the specification. Everything else is implementation.

## Keep the model creative inside bounded states

None of this means the model becomes a dumb function. Inside a state, the model has real freedom: how to interpret an ambiguous document, how to phrase the extraction, how to weigh conflicting signals. The creativity is bounded, not eliminated. Think of it like a talented employee with a clear job description: enormous latitude in how they do the work, zero latitude in whether the work gets reviewed before shipping.

The test for whether a state is well-designed: can you describe what the model may do inside it in one sentence, and what must be true to leave it in one guard clause? If the state's job is vague, split it. If the guard is vague, you have not finished the design.

There is a useful heuristic for deciding what becomes a state versus what stays emergent: anything with side effects, anything irreversible, anything regulated, and anything expensive becomes a state with guards. Pure reasoning, drafting, exploration, and summarization can stay looser. Draw the line where the cost of being wrong exceeds the cost of being explicit.

## What it looks like in practice

Abstract patterns are cheap, so here is the shape of a real implementation. The machine itself is boring, which is the point:

```
states = [ingested, classified, extracted, validated, complete,
          needs_review, failed]

transitions = {
  ingested:     [(classified,  always)],
  classified:   [(extracted,   always)],
  extracted:    [(validated,   schema_ok),
                (extracted,   retry_left),
                (failed,      retries_exhausted)],
  validated:    [(complete,    confidence_high),
                (needs_review, confidence_low)],
}
```

The guards, `schema_ok`, `retry_left`, `confidence_high`, are plain functions over the step output. The model never sees this table. It just does its job inside each state, and the machine moves it along. When you read an incident trace, you see exactly which transition fired and which guard decided it. Debugging becomes reading, not archaeology.

Notice what is missing: there is no "the model decides what to do next" anywhere in this design. That decision, the most consequential one in the workflow, belongs to code you can read, test, and review. Everything the model is genuinely good at, interpretation, judgment within bounds, handling ambiguity in the content, stays with the model. The division of labor follows the strengths: determinism where you need guarantees, intelligence where you need judgment.

## The objection, answered

The standard objection: state machines are rigid, and rigidity cannot handle the long tail. This gets it backwards. The state machine does not eliminate handling of the unexpected, it gives the unexpected a designed place to go. The `needs_review` state is the long tail's home: everything the machine cannot handle transitions there, with full context, for a human or a more capable process to deal with.

Emergent planning handles the long tail by improvising, which means every novel situation gets a novel, untested response. The state machine handles the long tail by routing it to the one place designed for novelty, with the trace intact. One of these is engineering. The other is hoping.

If your workflow has to work twice, write down the states. If it has to work a thousand times, write down the guards too. The model is brilliant inside the box. Your job is to build the box.

Which of your agent workflows is currently running on vibes, and what would its states be?
