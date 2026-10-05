---
layout: post
title: "Your Eval Set Is Lying to You"
description: "Most agent evals measure the demo, not the product. Why hand-written test cases flatter your system, and how to build evals that tell the truth."
date: 2024-12-15
tags: [evals, llm, production]
---

Every team I have watched ship an agent has the same ritual. Someone writes fifty test questions by hand, the agent passes forty-eight of them, everyone feels good, and then production users break it within a week. The eval set was not measuring the product. It was measuring the demo.

This is the streetlight effect applied to AI engineering: we test where the light is, which is wherever we happened to think of test cases, instead of where the failures are, which is in the long tail of real user behavior.

## Hand-written evals flatter the author

When you write a test case, you unconsciously write it in the style your system already handles. You phrase the request cleanly. You include the context the agent needs. You avoid the ambiguous, the misspelled, the underspecified, the weird. In other words, you write prompts that look like the ones you used while building the thing.

Real users do none of this. They write half a sentence. They reference things from three messages ago without quoting them. They ask for something your system was never designed to do, phrased as if it obviously was. Your hand-written eval set has zero coverage of any of this, and its 96 percent pass rate is a story you told yourself.

There is a second, subtler problem. The person writing the evals is usually the person who built the system, which means the evals encode the builder's mental model of the task. The gaps in your mental model, the cases you never considered, are exactly the cases missing from your evals. You cannot test what you cannot imagine, and production is an imagination-destroying machine.

## Sample from production, not from your head

The fix is unglamorous: log real traffic, sample it, and label it. Take a few hundred real user requests, strip anything sensitive, and have someone who did not build the system decide what the correct behavior is for each one. This is your golden set.

Three properties make a golden set honest:

**It is sampled, not authored.** Random or stratified sampling from real traffic preserves the true distribution of request types, including the ugly ones. If 30 percent of real requests are ambiguous, 30 percent of your eval set should be ambiguous. That will hurt your pass rate, and that is the point.

**It is labeled by someone else.** The builder's judgment about correct behavior is contaminated by knowledge of how the system works. A labeler who only sees the request and the output judges the thing users actually experience.

**It grows from failures.** Every production incident, every bad output a user reports, every surprising trace, goes into the eval set. Your evals should be a museum of your past mistakes, because the future will rhyme.

## The judge problem

Once you have real tasks, you need to grade them, and grading agent output at scale usually means an LLM judge. LLM judges are useful and dangerous in equal measure.

They are useful because human grading does not scale to hundreds of cases run on every change. They are dangerous because they have systematic biases: they prefer longer answers, they prefer confident tone over correct content, they agree with the position presented first, and they are easily fooled by outputs that look like the reference answer without being right.

If you use an LLM judge, calibrate it. Take a few dozen cases, grade them by hand, and measure agreement between the judge and the humans. If agreement is below what you would accept from a human grader, your judge is decoration. Also worth doing: run the judge on outputs you know are wrong but plausible, and see if it catches them. Most teams never test their tests.

And never, ever let the same model family that powers your agent also be the sole judge of it. That is asking the student to grade their own exam.

## Evals are a product, not a chore

The teams whose agents survive production treat evals as a first-class artifact: versioned, reviewed, extended with every incident, run in CI on every prompt and model change, with regressions treated like broken builds. The teams whose agents die treat evals as a checkbox they ticked once before launch.

Your eval set is a theory of what your users want. If that theory was written entirely inside your own head, it is fiction. Go read your logs. The truth is in there, and it is less flattering and far more useful than anything you would have written.

What is the most surprising thing you have found in your own production logs?
