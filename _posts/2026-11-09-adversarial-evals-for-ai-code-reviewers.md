---
layout: post
title: "Your AI Code Reviewer Has Blind Spots. Adversarial PRs Will Find Them."
description: "Most teams evaluate their AI code reviewer on PRs where they already know the bug exists. That measures recall on the easy cases and tells you nothing about the cases the reviewer silently misses. Adversarial PRs, defects deliberately seeded into realistic diffs, map the blind spots your golden set cannot see. How to build the suite, what the miss patterns teach you, and why the clean PR control matters more than the seeded bugs."
date: 2026-11-09
tags: [agents, evals, code-review, benchmarking, ai-engineering]
---

Most teams evaluate their AI code reviewer the same way: they collect a set of PRs where a real bug shipped, run the reviewer, and count how many it catches. Then they report a number and move on. That number is mostly useless. It measures recall on bugs someone already found, in diffs someone already decided were worth reviewing. It tells you nothing about the bugs the reviewer will silently wave through next week, because your golden set is a mirror of your own imagination. It only contains the failure classes you already thought to include.

Here is the thesis: the only way to map what a reviewer cannot see is to plant defects it has never seen and watch where it stays quiet. Adversarial evals are not a fancier benchmark. They are the difference between a reviewer you trust and a reviewer you merely hope works.

## The golden set is a mirror, not a window

I wrote about this problem in the ReviewBench post: an answer key only measures what the answer key contains. A golden set built from historical bugs has three blind spots baked in.

First, survivorship bias. A bug that made it into your golden set was found by a human. The bugs your reviewer misses in production are, by definition, the ones nobody found yet, or found too late. Your eval set systematically under-represents the exact failure mode you care about most.

Second, distribution skew. Real bug collections are heavy on the spectacular and light on the mundane. A null dereference that crashed prod gets written up. A missing idempotency key on a retry path, the kind of defect that double-charges a customer once a month, rarely makes it into a curated set. Yet the mundane defects are the ones a reviewer faces every day.

Third, staleness. Codebases drift. The bug classes that mattered last year are not the ones that matter now. A golden set that never gets new failure classes quietly decays into a test of the past.

An adversarial suite attacks all three at once. Instead of collecting bugs, you manufacture them. You take a real PR, seed exactly one defect into it, and ask the reviewer to find it. The defect is known, the diff is realistic, and the miss is unambiguous. When the reviewer stays silent, you have found a blind spot, not a debate.

## What an adversarial PR actually is

The design looks simple, and most of the design decisions are where teams go wrong. The rules that matter:

One defect per PR. If you seed three bugs and the reviewer finds one, you learn nothing clean about the other two. The reviewer might have stopped looking, or its attention might have been consumed by the first finding. Single-defect PRs give you a clean hit or miss per run.

Realistic diffs, realistic sizes. A 12-line diff with a glaring SQL injection teaches you nothing, because a linter would catch it and no human reviewer would miss it either. The defects worth testing are the ones a competent human catches only when they are paying attention: a flipped comparison in a boundary condition, an authorization check that validates the wrong field, a retry loop that reuses a non-idempotent request.

The defect has to be seeded into code the reviewer can actually reason about. If the bug requires context from a file that is not in the diff and not in the reviewer's context window, a miss tells you about your context plumbing, not about the reviewer's judgment. That is still useful information, but label it correctly. A miss caused by missing context is a retrieval problem. A miss caused by bad judgment is a reasoning problem. Conflating the two is how teams fix the wrong thing.

## A taxonomy of seeded defects

Adversarial suites work best when the defects are organized by class, because misses cluster by class, and the clustering is the whole point. A useful starting taxonomy:

**Correctness defects.** Off-by-one errors in pagination or slicing. A comparison flipped from `<` to `<=` at a boundary. An integer division where float division was intended. A loop that skips the last element. These are the defects a reviewer should catch from the diff alone, and they are the first thing to measure, because a reviewer that misses them is not reasoning about the code at all. It is pattern matching.

**Security defects.** The classic is string formatting into a query or a shell command. But the interesting seeds are subtler: an authorization check that compares the request's user ID against the resource's owner ID after the resource has already been fetched and mutated, a token expiry check that uses the token's issue time instead of its expiry time, a rate limit keyed on a user-supplied header. These separate reviewers that recognize security patterns from reviewers that reason about trust boundaries.

**Concurrency and ordering defects.** A check-then-act race on a balance update. A cache write that happens before the database commit it is supposed to reflect. An async task that reads a variable the caller mutates after scheduling. These are the defects where diff-local reasoning fails hardest, because the bug lives in the ordering of two operations that may sit in different functions.

**Contract defects.** A function that now returns an empty list instead of raising, while its caller still assumes an exception. A renamed field in a response object that a downstream consumer still reads by the old name. An API that starts returning timestamps in seconds where callers expect milliseconds. These test whether the reviewer tracks the contract between the changed code and its consumers.

**Idempotency and retry defects.** The retry loop that re-sends a non-idempotent request. The webhook handler that processes the same event twice because it records completion after the side effect instead of before it. The job that is safe to retry only because of an accident of ordering that the diff just broke. In my experience, this class produces the highest miss rate of any category, because the defect is invisible in the diff itself. It only exists in the relationship between the changed code and the system around it.

That last point generalizes. The miss rate climbs as the defect moves further from the diff. Diff-local defects get caught. Cross-file and cross-system defects get missed. That gradient is the single most important thing an adversarial suite can measure, because it tells you where your reviewer's effective reasoning radius ends.

## How to build the suite

Start small and mechanical. Pick a real repository the reviewer already reviews. For each seed, take a merged PR, revert one safety property in it, and keep everything else identical. The seed should be minimal: change as little as possible while introducing exactly one defect. A seed that rewrites half the function is testing the reviewer's tolerance for large diffs, not its judgment.

A concrete example. Here is a webhook handler before and after a seeded defect:

```python
# Before: completion is recorded before the side effect.
def handle_payment_webhook(event):
    if store.is_processed(event.id):
        return
    store.mark_processed(event.id)
    apply_payment(event.payload)

# After (seeded): the order is flipped. A crash or retry
# between apply_payment and mark_processed double-charges.
def handle_payment_webhook(event):
    if store.is_processed(event.id):
        return
    apply_payment(event.payload)
    store.mark_processed(event.id)
```

The diff is two lines swapped. A reviewer that understands idempotency catches it. A reviewer that reads code as text does not, because nothing in the changed lines looks wrong. The code is clean, idiomatic, and correct in isolation. It is only wrong in the world where processes crash and webhooks redeliver, which is to say, the real world.

Scoring needs to be strict. A hit means the reviewer flagged the seeded defect specifically, not that it left a comment somewhere near it. Vague observations like "consider error handling here" do not count. This sounds harsh, and it is supposed to be. Loose scoring is how a reviewer that writes ten generic comments per PR scores 90 percent recall while catching nothing a human would act on.

The scoring harness itself is small. The shape is a loop over seeded PRs, a run of the reviewer, and a judgment of whether the expected finding appears:

```python
for case in adversarial_suite:
    review = reviewer.review(case.diff)
    hit = judge.contains_finding(review, case.expected_finding)
    record(case.defect_class, hit, review.comment_count)
```

The judge can be a rubric, a second model, or a human spot check. What matters is that the judgment is about the specific defect, not about the general quality of the review. And the suite should record comment counts alongside hits, because the false positive rate is half the story.

## The clean PR control matters more than the seeded bugs

Every adversarial suite needs a control group: clean PRs with no seeded defect. Run the reviewer on them and count the comments. A reviewer that flags three things on every clean PR has a precision problem, and precision problems are what kill reviewers in practice.

Here is the mechanism. A reviewer that cries wolf trains developers to ignore it. The first time it flags a non-issue, the developer reads the comment carefully. The tenth time, they skim. The fiftieth time, they stop opening the review at all. At that point the reviewer's recall on real defects is irrelevant, because nobody is reading its output. A reviewer with 70 percent recall that developers actually read beats a reviewer with 95 percent recall that developers have learned to dismiss.

This is why hit rate alone is a vanity metric. The number that matters is the pair: hit rate on seeded defects, and comment rate on clean PRs. A good reviewer has a high first number and a low second number. A reviewer that maximizes only the first will spam its way to a good-looking score while destroying the trust that makes the tool usable.

Track the pair per defect class, not just in aggregate. It is common to find a reviewer that is excellent on style and correctness defects, silent on concurrency and idempotency defects, and noisy on clean PRs in exactly the areas where it is confident. That profile tells you something actionable: the reviewer is a good linter with a reasoning gap, not a bad reviewer overall. The fix is different for each profile. A reviewer that misses concurrency defects needs better context, longer reasoning, or explicit instructions to check ordering. A reviewer that spams clean PRs needs a higher bar for commenting, not a better model.

## The generator shares the reviewer's blind spots

There is a trap in generating adversarial defects with the same model family that powers the reviewer. If the generator cannot conceive of a defect class, it will never seed one, and the suite will inherit the exact blind spots it was built to find. The suite looks comprehensive. It is comprehensive within the generator's imagination, which is the same imagination the reviewer has.

Three mitigations, in order of strength. First, hand-write the seeds for the defect classes you care about most. Human-written seeds are expensive and slow, which is exactly why they cover ground no generator reaches. A dozen hand-written seeds in the idempotency and ordering classes are worth more than a hundred generated off-by-one seeds.

Second, generate seeds from a different model family than the reviewer, and from a different prompt. If the reviewer is a reasoning model prompted to find bugs, the generator should be a different model prompted to introduce them. The asymmetry matters: introducing a subtle defect is a different skill from finding one, and different models fail at it in different ways.

Third, mine real incidents. Every production incident with a code-level root cause is a seed waiting to be written. Take the fix commit, revert the safety property, and you have an adversarial PR grounded in a failure that actually happened. These seeds are the most valuable in the suite, because they are guaranteed to be realistic, and their miss rate is the closest thing you have to a measure of whether the reviewer would have prevented a real incident.

## What the miss patterns actually teach you

Run the suite a few times and the pattern that emerges is rarely "the reviewer is bad." It is usually a map. Misses cluster in specific classes, and each cluster points at a different fix.

Misses concentrated in one defect class mean a reasoning gap. The reviewer does not have the concept, or it has the concept but does not apply it under review conditions. The fix is targeted: add the class to the reviewer's instructions with a concrete example, or add a dedicated check for it. Generic instructions like "check for security issues" do almost nothing. A specific instruction like "verify that completion is recorded before any side effect in webhook handlers" does a lot.

Misses concentrated in large diffs mean an attention problem. The reviewer reads the first hundred lines carefully and skims the rest. The fix is structural: split the review, summarize the diff first, or review file by file with a shared summary. No prompt tweak fixes a reviewer that runs out of attention halfway through a diff.

Misses concentrated in cross-file defects mean a context problem. The reviewer never saw the file that makes the defect visible. The fix is retrieval: expand what gets included in the review, or add a step that pulls in callers and callees of changed functions. This is the most common cluster I see, and the most commonly misdiagnosed, because teams keep tuning the prompt when the reviewer simply never had the evidence.

False positives concentrated on clean PRs mean a calibration problem. The reviewer is rewarded, implicitly or explicitly, for finding things, so it finds things. The fix is to raise the bar for commenting: require the reviewer to state the concrete failure the comment prevents, and suppress comments that cannot name one. "This could be a problem" is not a finding. "This double-charges on redelivery" is.

## The honest trade-offs

Adversarial evals are not free. The suite needs maintenance: seeds rot as the codebase changes, and a seed that no longer applies to the current code is noise, not signal. Budget time for it, or the suite quietly becomes a test of last year's codebase.

There is also a calibration question. Some seeded defects are so subtle that a good human reviewer would miss them too. Including them is fine, but score them separately. A suite that mixes "a competent human catches this" with "only the author would catch this" produces a single number that means nothing. Tag each seed with a difficulty, human catchable or expert only, and report the numbers separately.

And there is a real risk of overfitting to the suite. If the team tunes the reviewer until it passes the adversarial set, the set stops measuring generalization and starts measuring memorization. Rotate seeds, retire ones the reviewer has seen too often, and keep adding new classes from real incidents. The suite is a living artifact, not a benchmark you publish once.

None of this is a reason not to build one. A reviewer without an adversarial suite is a reviewer whose blind spots are unknown, which is the same as a reviewer whose blind spots are everywhere. The suite does not make the reviewer perfect. It makes the imperfection visible, measurable, and fixable, one defect class at a time.

The question that matters is not whether your reviewer catches bugs. It is whether you know which bugs it cannot catch. If you cannot name them, you have not evaluated your reviewer. You have admired it.

What is the defect class your reviewer misses most often, and how did you find out?
