---
layout: post
title: "Benchmarks Measure Benchmarks"
description: "Leaderboard gains often measure the benchmark, not the capability. How to read benchmarks without fooling yourself."
date: 2025-01-20
tags: [benchmarking, evals]
---

The leaderboard goes up. The product does not get better. Everyone in AI has watched this happen, and most of us have participated in it: a new state of the art is announced, the number is real, the improvement is not. The benchmark moved. The capability did not.

This is not a complaint about benchmarks. Benchmarks are useful. It is a complaint about what we pretend they are. A benchmark is a measurement of performance on a specific set of tasks, under specific conditions, scored a specific way. That is all it is. Everything beyond that sentence is storytelling.

## Goodhart's law, applied to leaderboards

When a measure becomes a target, it ceases to be a good measure. Benchmarks are targets now. Entire research programs optimize directly against them: training on similar data, tuning prompts to the benchmark's format, selecting checkpoints by the leaderboard number, engineering the system around the test's quirks.

None of this is cheating, exactly. It is the rational response to incentives. But it means the number you are reading is not "how good is this system at the underlying capability." It is "how good is this system at this benchmark," and those diverge exactly in proportion to how hard everyone tried.

The honest version of most leaderboard claims would read: "under the conditions of this test, which we studied carefully and optimized for, our system scores X." That is still informative. It is just not the same as "our system is better at the thing."

## Contamination: the test is in the training set

The dirty secret of benchmark science is contamination. Benchmarks are public. Training corpora are the internet. The test set, or near paraphrases of it, ends up in training data with depressing regularity. A model that has seen the test questions during training is not demonstrating capability; it is demonstrating recall.

Detecting contamination is genuinely hard, which is why so little of it happens. The practical defenses: prefer benchmarks with held-out test sets that are never published, prefer benchmarks that refresh their questions, and treat any huge jump on a long-public benchmark with the skepticism it deserves.

There is a stronger version of this worth internalizing: if a benchmark has been public for years and models keep climbing it, some unknown fraction of the climb is memorization. You cannot separate it out after the fact. The number is polluted and there is no filter.

## Narrow distributions, broad claims

Every benchmark samples from some distribution of tasks. Almost all of them sample narrowly: short questions, single-turn, English, clean formatting, unambiguous answers. Then the score gets cited as evidence about the capability in general, including long multi-turn messy real-world use that looks nothing like the test.

This is the fundamental attribution error of benchmarking. The score describes the intersection of the system and the test distribution. Change the distribution and the ranking can invert. A model that dominates short-form QA can stumble on extended reasoning; a system tuned for the benchmark's format can collapse when users do not follow the format.

Before trusting a benchmark, ask what distribution it samples and whether that distribution resembles your use case. If the answer is no, the number is entertainment, not evidence.

## Metric gaming

Even honest benchmarks get gamed by their metrics. A metric that rewards exact match punishes correct paraphrases. A metric scored by an LLM judge inherits the judge's biases toward length and confidence. A pass@k metric rewards systems that generate many attempts, which tells you nothing about single-shot reliability.

Always read the metric before the number. Ask what behavior it rewards and what it ignores. Then ask whether the rewarded behavior is what you actually want. More than once I have seen a "better" system that was simply better at producing the metric's preferred shape of output.

## What makes a benchmark trustworthy

Not all benchmarks are theater. The ones worth paying attention to share properties:

**Held-out and refreshed.** The test set is not public, or it rotates. This is the single strongest defense against contamination.

**Task diversity.** The benchmark covers the range of the capability, not one convenient slice. Look for subscores by category, and read them; the headline number hides the variance.

**Human baselines.** A score means more when you know what humans score. It calibrates difficulty and exposes tests where the metric diverges from human judgment.

**Error analysis, not just scores.** The valuable part of a benchmark is rarely the ranking. It is the failure taxonomy: what kinds of tasks does the system get wrong, and why. A benchmark that only publishes a number is a scoreboard. One that publishes error analysis is a research tool.

## Use benchmarks as one signal among many

The healthy relationship with benchmarks: they are a signal, not a verdict. Use them to sanity-check that a system is in the right ballpark, to compare candidates before deeper evaluation, to notice when something regresses. Then do the real work: evaluate on your own tasks, sampled from your own distribution, labeled by your own standards.

Because here is the thing nobody wants to say: the only benchmark that matters for your product is your product's tasks. Public leaderboards measure public tasks. Your users do not live on the leaderboard. They live in the messy distribution the benchmark abstracted away, which is exactly where the leaderboard-optimized system is weakest.

Build your own evals. Sample from production. Label honestly. Version them. Run them on every change. It is unglamorous and it is the only measurement you can actually trust, because it is the only one measuring the thing you ship.

## Getting off the treadmill

So what does a healthy evaluation practice look like for a builder? It inverts the default priority. Public benchmarks become what they should have been all along: a coarse triage signal, useful for ruling out systems that are clearly not in the running, useless for choosing among serious contenders.

The primary loop is your own evals, built from your own distribution. Sample real tasks, label them honestly, version the set, and run it on every meaningful change. When the public leaderboard says a new model is better but your evals say otherwise, trust your evals. They are measuring your product. The leaderboard is measuring the leaderboard.

And then do the thing almost nobody does: red-team your own evals. Ask what behaviors your eval set rewards that your users would not want. Check whether your labels encode your own blind spots. A private eval set can be gamed just like a public one, more quietly, because nobody is watching. The discipline that makes benchmarks trustworthy, held-out data, diverse tasks, error analysis, applies to yours too.

There is a deeper point here about what progress means. A field that optimizes a fixed set of tests will converge on systems that are excellent at those tests, which is not the same as systems that are excellent at the underlying work. The gap between the two is where the interesting problems live: the tasks nobody benchmarked, the distributions nobody sampled, the failures nobody taxonomized. If you want to do work that matters, look at the gap, not the leaderboard.

## The close

Benchmarks measure benchmarks. Your users measure your product. Make sure you know which one you are optimizing.

Which benchmark do you trust, and what specifically earned that trust?
