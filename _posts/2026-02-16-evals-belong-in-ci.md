---
layout: post
title: "Evals Belong in CI"
description: "Run your golden set on every prompt and model change. Treat eval regressions like broken builds."
date: 2026-02-16
tags: [evals, engineering]
---

I have written before about building an honest eval set, sampled from production traffic and labeled by someone who did not build the system. That is the hard part. This post is about the part teams skip after doing the hard part: they build the golden set, run it once, feel good, and then let it rot. Six months later the prompt has changed forty times, the model has been swapped twice, and nobody has run the evals since launch week.

An eval suite that runs manually before big launches is theater. It exists so someone can say evals were run. The discipline is continuous: every prompt edit, every model swap, every tool change runs the golden set automatically, and a regression blocks the change the same way a failing test blocks a deploy.

## Wire it into the deploy path

The mechanism is boring, which is why it works. Your eval suite is a script. It takes a system configuration (prompt versions, model identifiers, tool definitions) and returns a score per case plus an aggregate. Your deploy pipeline calls that script on every change to anything the agent depends on, and the change does not ship unless the score clears the bar.

This means prompts, model selections, and tool schemas have to be versioned artifacts, not strings someone edits in a console. If a change cannot be named, it cannot be gated. The first step of evals in CI is treating every input to agent behavior as code: reviewed, versioned, and tested.

The pipeline itself is straightforward:

```
on change to prompts/, models.yaml, or tools/:
  run eval suite against staging
  compare aggregate score to baseline
  if regression beyond threshold: block merge, notify owner
  if pass: record score, allow merge
```

The interesting decisions are all in the details: what counts as a regression, how to handle flakiness, and who owns a red suite.

## Track scores over time, not just pass or fail

A binary gate is the minimum. The real value is the trend line. Log every eval run with its configuration hash and scores, and plot them. Slow degradation is the most common failure mode of agent systems in production: no single change breaks anything, but twenty small changes each cost a point, and one day you notice the agent is noticeably worse and nobody can say when it happened.

Score history answers that question. It also changes how teams behave. When every prompt tweak shows up as a number on a dashboard the next morning, people stop making casual edits. The eval suite becomes the shared definition of "working," and arguments about whether a change helped become lookups instead of debates.

Track per-case scores too, not just the aggregate. Aggregates hide movement: a change that fixes ten cases and breaks ten different ones looks neutral in the total while churning behavior users depend on. Per-case diffs on every run tell you what actually moved.

## Flake management: statistics, not exact match

Here is the objection everyone raises: model outputs are nondeterministic, so evals are flaky, so gating on them is madness. The objection confuses determinism with measurability.

You do not need exact-match grading. You need statistical thresholds. Run each case a few times, or run the suite and compare against a baseline with a tolerance band. A case that passes 9 times out of 10 on the baseline and 2 times out of 10 on the new config is a regression even though neither run was deterministic. This is standard practice in every field that measures noisy systems. AI engineering just has to learn it.

Concretely:

**Grade with rubrics or judges, not string equality.** Exact match on generated text is brittle by design. Score on the properties that matter: did it call the right tool, did the answer contain the required facts, did it refuse when it should have.

**Set thresholds from data.** Run the suite against the current production config several times. The variance you observe is your noise floor. A regression is a drop that exceeds it. Do not pick thresholds from intuition.

**Quarantine chronic flakes.** A case that flips randomly regardless of config is not measuring anything. Move it to a quarantine set that runs for information but does not gate. Fix or delete quarantined cases on a schedule, or the quarantine becomes a graveyard where signal goes to die.

**Seed what you can.** Temperature zero and fixed seeds do not make models deterministic, but they reduce variance enough to matter. Control what is controllable.

## Make the gate fast enough to respect

A gate people dread is a gate people bypass. If the full suite takes two hours, nobody will wait for it on every prompt tweak, and your beautiful pipeline will be circumvented by Friday. Speed is a design requirement, not a nice-to-have.

The standard answer is tiers. A smoke set, fifty to a hundred fast cases covering the critical paths, runs on every change and gates the merge. The full suite, thousands of cases including the slow multi-step ones, runs nightly and on release candidates. The smoke set catches the obvious breakage immediately; the nightly catches the slow drift. This is exactly how mature software teams treat unit versus integration suites, and the mapping carries over cleanly.

Parallelize aggressively. Eval cases are independent by construction, so there is no reason to run them sequentially. Fan the suite out across workers and the wall-clock time collapses. The cost of the compute is trivial next to the cost of an engineer waiting, or worse, not waiting.

And measure the gate itself. Track how long the suite takes, how often it flakes, how often a red run turns out to be real. A gate with a 30 percent false-positive rate will be ignored no matter what the policy says. Keep the signal clean enough that red means something, because the day red stops meaning something is the day your evals become theater again.

## Who owns a red suite

The sociological failure mode: the eval suite goes red, nobody owns it, and the team learns to ignore it. A gate everyone walks around is worse than no gate, because it teaches the organization that quality signals are optional.

Ownership has to be explicit. One person or one rotation owns the suite: keeping cases fresh, investigating regressions, deciding when a red run is a real regression versus a bad case. And the rule has to be absolute: red means stop. The moment someone merges past a red eval suite "just this once," the suite is decorative.

There is a subtler ownership question: who decides what "correct" means when a case starts failing? Sometimes the world changed and the old expected behavior is wrong. Updating the golden set is legitimate, but it must be a deliberate, reviewed act, not a quiet edit to make the red go away. Every change to expected behavior is itself a product decision. Treat it like one.

## The compound interest argument

None of this is exciting. It is plumbing. But consider what it buys over a year: every change measured, every regression caught at merge time instead of discovered by users, a complete history of how behavior evolved, and a team that treats agent behavior as an engineered property rather than a vibe.

The teams that do this ship faster, not slower, because they stop being afraid of changes. When the suite is green you merge with confidence. When it is red you know exactly what broke. The alternative, manual evals before launches, means every release is a leap of faith and every incident is a surprise.

Your eval set is the specification of what your system is supposed to do. Run the spec on every change. That is what CI is for.

How are your evals wired into your deploy path today, and what is stopping you from gating on them?
