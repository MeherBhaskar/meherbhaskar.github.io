---
layout: post
title: "The Answer Key Is the Benchmark: What GitHub's ReviewBench Gets Right and Wrong"
description: "GitHub's new open benchmark for AI code reviewers has the best-designed metric family of any agent eval this year, and a conflict of interest baked into its answer key. On augmented metrics, judge recursion, and the three trust questions every benchmark must answer."
date: 2026-10-16
tags: [evals, benchmarking, agents, code-review]
---

Most benchmark arguments are fought over the leaderboard. That is the wrong layer. The leaderboard is the output of three design decisions made before any agent was scored: who generated the answer key, who judges what the key missed, and whether the builder also sells a contestant. GitHub's ReviewBench, launched October 5 as a research preview for evaluating AI code reviewers, deserves attention because it answers one of those questions better than any benchmark I have seen, and fumbles the other two in ways the whole field keeps repeating.

I wrote last week about [what building RigorBench taught me](https://meherbhaskar.github.io/2026/10/06/what-rigorbench-taught-me-about-benchmarking-agents/) about benchmarking agents: single scalars lie, trajectories are the real evidence, and benchmarks are governance. ReviewBench is the first major release since that post that lets me test those claims against someone else's design. The results are flattering and uncomfortable in roughly equal measure.

## The setup, briefly

The corpus: 219 pull requests from 187 open-source repositories across 19 languages, sampled to match the language and repository-size distributions of 103.9 million GitHub PRs, deliberately weighted away from tiny one-file edits toward substantive multi-file changes. The golden set combines human review findings, issues inferred from follow-up fix commits, static analysis, and several frontier LLMs, merged by semantic dedup and labeled under one rubric. The judge is Claude Sonnet 5. Senior engineers independently re-labeled the findings and agreed with the benchmark's true-positive labels 96.6% of the time. The repo is MIT-licensed: dataset, judge prompts, runner, all public. You wrap your reviewer in a container, validate on a 25-PR test set, then run the full 219 over three rounds with your own model key. Initial leaderboard: Copilot Balanced at 26.0% grounded recall and 87.8% precision, Devin 23.8%, Qodo 22.1%, Cursor 9.6%.

## What it gets right: augmented metrics

Every golden set is incomplete. That is not a flaw in ReviewBench's data collection. It is a fact about the world: no panel of reviewers, human or model, catches every issue in a pull request. Standard benchmark design pretends otherwise. A finding outside the golden set gets scored as a false positive, which means the benchmark punishes a reviewer for finding a real bug that nobody else found. Every team running an AI reviewer has lived this: the tool flags something genuine, the process treats it as noise, and the team learns to distrust the tool. A grounded-only metric bakes that failure mode into the scoreboard.

ReviewBench splits the metric into two families. Grounded precision and recall measure against the fixed golden set: the strict, like-for-like cross-system comparison. Augmented precision and recall also credit valid findings outside the set, with the same judge deciding whether an unmatched finding is real. Grounded ranks; augmented diagnoses. The logic is simple enough to write down:

```python
def score_reviewer(findings, golden_set, judge):
    matched, unmatched = match_against(findings, golden_set)
    valid_novel = [f for f in unmatched if judge.is_valid(f)]
    grounded_recall = len(matched) / len(golden_set)
    # denominator is per-agent: it includes this agent's own discoveries
    augmented_recall = (len(matched) + len(valid_novel)) / (len(golden_set) + len(valid_novel))
    return grounded_recall, augmented_recall  # one compares, one diagnoses
```

The part I respect most is the caveat, printed in the methodology rather than buried: augmented recall uses a per-agent denominator, so it is not comparable across agents. Two reviewers with identical augmented recall numbers can mean different things, because each number's denominator includes that agent's own discoveries. GitHub resists the temptation to turn the generous metric into a ranking metric. Most benchmarks would not resist. The leaderboard sorts by grounded F1, with slicing by severity, category, and a tunable beta in the F-beta score. That is the per-dimension default I argued for after RigorBench: the breakdown as the view, the aggregate as the footnote.

## What it gets right: distribution and offline-to-online evidence

Two more things ReviewBench gets right. First, corpus construction. The team analyzed 103.9 million PRs, then weighted the corpus toward the reviewable middle and tail instead of letting tiny single-file changes dominate. That is evaluation design as product thinking: measure the changes where review quality actually matters, not the ones that are easiest to collect.

Second, the strongest claim in the whole release: GitHub reports that offline results predicted production A/B outcomes. In a multi-model ensemble experiment, the online A/B showed +8.0% precision, +13.6% recall, and -8.0% cost per review, while critical comments were predicted at +227% offline and measured at +262% online. Say the caveat plainly: this is GitHub's own report, with its own product in the mix. But as evidence that offline benchmark movement can predict production movement, it outruns anything else published this year. Most agent benchmarks never even attempt the comparison. Direction and magnitude both landing is the kind of result that should make every eval team ask why their benchmark cannot say the same.

## What it gets wrong: judge recursion

Now the problems. The judge wears two hats. Claude Sonnet 5 applied the rubric that produced the golden labels, and it also decides whether each agent's novel findings are valid. One model with one set of blind spots sits on both sides of the scoring. If Sonnet 5 systematically undervalues, say, concurrency hazards, those findings are thin in the golden set, and the augmented judge is unlikely to credit agents that surface them. The recursion is the same one I hit in RigorBench, where LLM judges scored trajectories against rubrics: you are evaluating agents with the same class of models you are evaluating, and the judge's blind spots become the benchmark's blind spots.

To be fair, ReviewBench publishes a calibration number, the 96.6% engineer agreement figure, which is better than what we shipped. But agreement with the true-positive labels is not agreement on the hard calls. The hard calls are the augmented ones: whether an unmatched finding is valid. That is exactly where the judge's dual role bites, and it is the number that is not published. The metric I want to see next is judge-versus-engineer agreement on the unmatched findings themselves, the augmented decisions, not just the golden set.

## What it gets wrong: the answer key's conflict of interest

The sharper problem is provenance. RuntimeWire's analysis of the public dataset found that Copilot Code Review, GitHub's own product, supplied 1,185 of the golden set's 2,623 true-positive findings, roughly 45%, and that the 96.6% agreement figure was computed over a subset of findings already labeled true positive. That same product sits atop the initial grounded-recall leaderboard at 26.0%.

The methodology is public. The repo is MIT-licensed. GitHub documents that the initial entries were run by the ReviewBench team on vendors' public products, and that vendors did not run or verify them. None of this is hidden. But transparency about a conflict is not the same as resolving it. When the contestant contributed nearly half the answer key, grounded recall partly measures how well the golden set agrees with that contestant's priors, not just how well each contestant finds real bugs. A reviewer whose failure modes resemble Copilot's gets a friendlier key than one with a genuinely different, equally valid notion of what matters in a review.

The fix is known and cheap: exclude the evaluated product's own findings from the answer key when scoring that product, and publish the source composition of every golden finding so anyone can recompute the leaderboard under different exclusions. My opinion, stated plainly: any benchmark builder that also sells a contestant should ship that exclusion by default. A note that says "we also make Copilot" is disclosure. A scoring design that cannot favor your own product is integrity.

## The three questions

So here is my checklist for any agent benchmark, borrowed from ReviewBench's design and its gaps:

1. Who generated the answer key, and can I see the source composition?
2. Who judges what the key missed, and is that judge the same model that built the key?
3. Does the builder sell a contestant, and does the scoring exclude the builder's own contributions by default?

ReviewBench earns the best answer the field has to question two, a careful but incomplete answer to question one, and a dodge on question three. Read it as both a template and a warning. The sharpest thesis I can offer: a benchmark is not a dataset with a leaderboard. It is three trust decisions with a dataset attached. ReviewBench proves how good the good decisions can look, and how much the bad ones can cost, in the same release.

What is one finding your current eval setup would score as a false positive that your engineers would call a catch?
