---
layout: post
title: "What RigorBench Taught Me About Benchmarking Agents"
description: "Building RigorBench forced me to confront uncomfortable truths: outcome metrics lie about agents, single scalars hide tradeoffs, and abstention is a skill benchmarks usually punish."
date: 2026-10-06
tags: [evals, benchmarking, agents]
---

Most teams evaluate coding agents the way they evaluate compilers: feed in a task, check whether the output passes tests. The tests pass, the team ships, everyone feels good. The tests tell you the code works. They tell you almost nothing about the agent.

This is the central mistake I kept running into while building RigorBench, the benchmark my brother and I put out this summer (paper on [arXiv](https://arxiv.org/abs/2606.22678), code at [github.com/MeherBhaskar/RigorBench](https://github.com/MeherBhaskar/RigorBench)). The field evaluates agents on outcome correctness: does the generated code pass tests or resolve issues. RigorBench measures something else: engineering process discipline, how the solution was reached. Planning, verification, recovery, knowing when to stop.

Building it changed how I think about evaluation itself. Here is what I learned.

## The single scalar lies

Every benchmark wants a leaderboard, and every leaderboard wants a number. We computed a composite RigorScore: a weighted sum across five pillars (seven in the later revision). And immediately we hit the problem every benchmark hits. The aggregate hides the interesting story.

In our runs, different harnesses won different pillars. One harness had the highest clarification discipline: it paused to ask for context before writing code. Another dominated specification coverage. Another won exploration efficiency. The baseline beat everyone on regression resilience. If you only look at the composite, you conclude one harness is "best." If you look per pillar, you see something truer: process discipline is not a monolith. Different architectures trade off planning precision against test quality against interactive clarification.

This is not a RigorBench problem. It is a benchmark problem. SWE-bench reports resolved-rate. HumanEval reports pass@k. A single number makes comparisons easy and conclusions cheap. But agent architectures are bundles of distinct behaviors, and a scalar average smears them into a ranking that misleads everyone who acts on it. If you choose a harness because it ranks first on a leaderboard, you may be buying excellence in a pillar you do not care about and weakness in one you do.

Opinion, stated plainly: benchmarks should make the per-dimension breakdown the default view and the aggregate the footnote, not the reverse. A leaderboard that cannot show you *where* an agent is strong is not measuring. It is ranking.

## Trajectories are the evidence, outcomes are the verdict

The single most load-bearing design decision in RigorBench was scoring the full execution trajectory, not just the final artifact. Every tool call, every file read, every test run, every rewrite. That is where process discipline lives. You cannot measure planning fidelity from a diff. You cannot measure recovery efficiency from a passing test.

Trajectory scoring is harder to game than outcome scoring. If an agent memorized a solution, the trajectory still shows a blank: no exploration, no verification, no reasoning trace. An agent that stumbled into the right answer through reckless trial and error gets a very different process score than one that planned, verified, and recovered cleanly, even though both produced identical passing code.

But here is the honest trade-off: trajectory evaluation is expensive and subjective. Outcomes can be judged by running tests. Trajectories need judges, and we used LLM judges with structured rubrics. That makes scoring cost a real constraint, introduces judge variance, and creates a recursion problem: you are evaluating agents with the same class of models you are evaluating. I wrote about not trusting LLM judges blindly in an earlier post, and building RigorBench taught me the practice, not just the principle. Rubrics need calibration examples. Pillars need crisp definitions. "Verification coverage" has to mean something a judge can apply the same way twice, or your metric is noise wearing a costume.

The lesson generalizes. Any serious agent eval program eventually moves from outcome judgments to process judgments, because outcomes saturate and process is where the real differences hide. When you make that move, you inherit a measurement problem that tests never had. Plan for it: calibrated rubrics, sampled human spot-checks, and the humility to report variance instead of hiding it.

## Design tasks that probe failure, not just success

Standard benchmark tasks ask: can the agent do the thing? That question selects for capability and ignores conduct. An agent that solves 60% of tasks recklessly is worse, in production, than one that solves 50% carefully and refuses the rest. So we designed task categories around failure behavior:

- **Doom Loop Gauntlet**: tasks where the natural failure mode is a loop, repeated failing attempts with diminishing returns. Does the agent detect the loop and change strategy, or burn tokens in circles?
- **Know When to Fold**: tasks that are underspecified or impossible. The correct behavior is abstention: stop, ask, or decline. This is a skill, and it is measurable.
- **Don't Break the Build**: tasks scored partly on what the agent did *not* touch. Did unrelated behavior stay intact?
- **Verify-Or-Die**: tasks where shipping without tests is the failure mode being measured.
- **Plan-Then-Build**: tasks where a good plan is half the score.

The contrarian claim, earned the hard way: abstention quality was one of the most informative things we measured, and almost every benchmark in existence either ignores abstention or actively punishes it. A benchmark where declining counts as a zero teaches agents to never decline. Then we deploy those agents and act surprised when they hallucinate a database migration instead of saying "I don't have enough information." You get the behavior you score. If your eval never rewards stopping, your agents never learn to stop.

## A benchmark is a specification for the market

The uncomfortable meta-lesson: benchmarks are governance. Whatever a benchmark measures, the field optimizes. Outcome-only benchmarks trained the industry to build agents that produce passing code by any means. Trial and error, no plans, no verification, no recovery strategy, and no graceful degradation. That is not a failure of the agents. That is the industry responding to the metric it was given.

When we showed that structured process discipline correlates strongly with outcome quality, the interesting number was not the correlation. It was the direction of causality the data suggested. Process quality moved first, outcomes followed. In our controlled with/without runs, adding a discipline framework improved process scores substantially and pulled outcome correctness up with them. Discipline is not decoration on top of capability. It is load-bearing.

So the sharpest thesis I can offer: if you care about agents you can trust in production, stop letting benchmarks that measure only outcomes define what a good agent is. The gap between what agents produce and how they produce it is where production failures live. Measure the how.

## A sketch, because concrete beats abstract

For the skeptics who think "abstention quality" is unmeasurable, here is the shape of the rubric. Real implementations need calibration examples, but the logic is simple:

```python
def score_abstention(trajectory, task):
    if task.is_solvable:
        # Did the agent needlessly quit or ask?
        if trajectory.early_abandon:
            return 0.0
        return 1.0 if trajectory.exhausted_reasonable_attempts else 0.5
    else:
        # Task is underspecified or impossible. The right move is to stop.
        if trajectory.clarified_or_declined_before_irreversible_action:
            return 1.0
        if trajectory.shipped_a_guess:
            return 0.0
        return 0.3  # flailed, then gave up; better than shipping a guess
```

The crucial line is the one that scores "shipped a guess" as 0.0. Most benchmarks score that attempt as a 1.0 when the guess happens to pass tests. That is a choice with consequences.

## What I would do differently

Two things. First, we should have frozen the pillar set before scoring at scale. We shipped v1 with five pillars and added two more in v2 (test assertion density, exploration efficiency), which means v1 and v2 scores are not directly comparable. That was a real cost, paid in rerun time and in leaderboard confusion. If you build a benchmark, version the scoring rubric like an API: adding a metric is a breaking change, and breaking changes need a migration story.

Second, contamination is an unsolved problem for public trajectory benchmarks, not just a footnote. Emphasizing trajectories over outcomes helps, because trajectories are harder to memorize into weights than answer strings. Multiple valid solution paths help. But I am less confident than the paper's limitations section sounds. Proctored execution, where the evaluation environment is held back rather than published, is probably the honest long-term answer for anything that claims to measure frontier capability.

## The one-line version

Benchmarks are not neutral measurement instruments. They are incentive systems that the whole field optimizes against. If your benchmark rewards only outcomes, you will get agents that produce outcomes by means you cannot see, control, or trust. Measure the process, or inherit the processlessness.

What is the one behavior your current evals do not reward that production desperately needs from your agents?
