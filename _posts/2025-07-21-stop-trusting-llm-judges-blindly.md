---
layout: post
title: "Stop Trusting LLM Judges Blindly"
description: "LLM judges are useful and systematically biased. Calibrate them like any other instrument or stop pretending they measure."
date: 2025-07-21
tags: [evals, llm]
---

The LLM judge has become the default answer to the hardest problem in agent engineering: how do you grade open-ended output at scale? It is fast, it is cheap, it never gets tired, and it is systematically biased in ways most teams never measure.

I am not saying do not use LLM judges. I am saying stop treating them as oracles. A judge is an instrument, and instruments need calibration. Nobody would deploy a thermometer without checking it against a known temperature. Yet teams deploy judges that have never been tested against a single hand-graded example, and then make shipping decisions on the scores.

## The biases are systematic, not random

Random noise in a judge is annoying but manageable: it washes out over enough samples. Systematic bias is worse, because it consistently pushes your decisions in one direction while looking like measurement.

**Length bias.** Judges prefer longer answers. Not slightly, substantially. Given two correct answers, the judge picks the longer one. Given a correct short answer and a wrong long one, the judge too often picks the wrong long one. This is catastrophic for optimization: if your evals reward verbosity, your system will learn to be verbose, and you will interpret the rising scores as improvement.

**Confidence bias.** Judges confuse confident tone with correct content. An answer that hedges appropriately ("this is likely X, but Y is possible") loses to an answer that asserts wrongly with conviction. Your agent learns that hedging is punished, so it stops hedging, so your users get confident wrongness instead of honest uncertainty. The eval set is actively training away the behavior you want.

**Position bias.** Present two options and the judge favors the first. Swap the order and the preference flips. Any pairwise comparison done without order randomization is measuring position, not quality.

**Plausibility blindness.** This is the worst one. Judges are easily fooled by outputs that look like the reference answer without being right: same structure, same terminology, same confident shape, wrong substance. The better your agent gets at mimicking the surface of good answers, the less your judge can tell the difference. The instrument degrades exactly as the system improves.

None of these are secrets. They are all documented. And almost nobody tests for them.

## The calibration protocol

Calibrating a judge is straightforward. It takes an afternoon. There is no excuse for skipping it.

**Step one: hand-grade a sample.** Take fifty to a hundred outputs, covering the range of quality your system produces. Grade them yourself, or better, have someone who did not build the system grade them. These human grades are your ground truth. Yes, human grading is noisy too, which is why you want two graders on a subset and a measure of their agreement. If the humans cannot agree, the task is not gradeable, and no judge will save you.

**Step two: measure agreement.** Run the judge on the same sample and compute agreement with the human grades. Not correlation, agreement: on what fraction of cases do judge and human reach the same verdict? Decide in advance what agreement rate you would accept from a human grader, and hold the judge to the same bar. If a human grader at 80 percent agreement would be fired, a judge at 80 percent is not a judge, it is a random number generator with good PR.

**Step three: adversarial testing.** This is the step everyone skips. Construct outputs you know are wrong but plausible: correct structure with a flipped conclusion, confident tone with fabricated details, answers that parrot the reference's phrasing while changing the meaning. Run the judge on them. If it cannot reliably catch known-wrong outputs, it cannot be trusted on unknown ones. Most judges fail this test badly, and most teams never administer it.

**Step four: bias probes.** Test each known bias directly. Same answer at two lengths: does the score change? Same content in both positions: does the verdict flip? Correct-but-hedged versus wrong-but-confident: which wins? Document the biases you find. You will find some.

**Step five: recalibrate on change.** A judge calibrated for one task, one model, one prompt style is calibrated for exactly that. Change the system under test and the judge's biases shift. Re-run the protocol whenever the thing being judged changes meaningfully. Calibration is not a one-time event, it is maintenance.

## Rubrics beat vibes

Most judge prompts are embarrassingly vague: "Rate this answer from 1 to 5." A 1-to-5 scale with no rubric is not measurement, it is mood. The judge invents its own criteria on the fly, and those criteria drift between runs, between models, between Tuesdays.

Write the rubric like you would for a human grader, because that is what the judge is replacing. Define each level with concrete, checkable criteria: "5: correct conclusion, all key evidence cited, no fabricated details. 3: correct conclusion but missing evidence or minor inaccuracies. 1: wrong conclusion or fabricated evidence." The more operational the criteria, the less room for the judge's biases to operate.

Two further disciplines help. First, reference-based judging beats reference-free whenever you have references: comparing against a known-good answer is more grounded than asking the judge to evaluate in a vacuum. Second, have the judge reason before scoring, then score separately: "First list the specific strengths and weaknesses, then assign the score." The reasoning step forces the judge to commit to observations before the number, which measurably reduces snap judgments. Discard the reasoning or keep it, but make the verdict follow the evidence, not precede it.

And revisit the rubric itself. When the judge's scores and your own reading of outputs diverge, the rubric is often the problem: it rewards what is easy to check rather than what matters. A rubric is a theory of quality. Theories need updating.

## Never let the student grade the exam

One rule with no exceptions: the model family powering your agent cannot be the sole judge of it. Same model, same training data, same blind spots, same stylistic preferences. It will reward outputs that look like its own, punish approaches it would not take, and share every systematic error the agent has. The correlation between agent and judge is not a feature, it is a conflict of interest.

Use a different model family for the judge, or better, an ensemble of judges from different families with disagreement flagged for human review. The ensemble costs more, which is the point: grading is part of the product, not overhead to minimize.

And keep a human-graded holdout set that the judge never sees during development. Run it periodically. If judge scores and human scores diverge over time, the judge has drifted, or the system has learned to game it. Either way, you need to know.

## When humans are still required

Some things judges cannot do, and the list is longer than the industry admits. Novel failure modes, by definition, are not in the judge's rubric. Subtle factual errors in domains the judge is weak on. Anything where the cost of a wrong grade exceeds the cost of grading: high-stakes decisions, safety-relevant outputs, anything user-facing where a bad grade means a bad ship decision.

The honest framework: use judges for scale, humans for truth. Judges run on every change, over hundreds of cases, catching regressions cheaply. Humans grade samples continuously, calibrating the judges and catching what the judges cannot see. Neither replaces the other. A team with only judges is flying on uncalibrated instruments. A team with only humans cannot iterate.

Your evals are only as honest as your grader. Calibrate the instrument, probe its biases, keep the student away from the answer key, and never stop spot-checking with human eyes. The teams that do this ship with confidence. The teams that do not ship with scores.

When did you last hand-grade a sample of your judge's verdicts?
