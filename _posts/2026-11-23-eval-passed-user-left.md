---
layout: post
title: "The Eval Passed and the User Left"
description: "Your eval suite reports 94 percent. Your user hit the 6 percent and never came back. Aggregate scores hide the single worst experience, and that experience is the one that decides whether anyone trusts your agent. How to budget for tail failures the way SRE budgets for downtime."
date: 2026-11-23
tags: [llm-evaluation, agents, evals, production-ai, reliability, ai-engineering]
---

Your eval suite reports 94 percent. The release ships. Then a user hits the 6 percent, gets a confidently wrong answer on the one task they actually cared about, and never comes back. They do not file a bug report. They do not leave a comment. They just leave. Your dashboard still says 94 percent.

Here is the thesis: aggregate eval scores measure your agent's average day. Users do not experience your agent's average day. They experience one run, and if that run is the worst one, the average is irrelevant. A pass rate is a summary of how often things go right. Trust is decided by how badly things go wrong, and how often the worst case shows up.

Most practitioners get this wrong in a specific way. They treat the eval score like a grade, and they manage it like one. The score goes from 91 to 94, the team celebrates, the release ships. Nobody asks what the 6 percent contains. The 6 percent is not a uniform fog of mild imperfection. It has a shape. It contains the failures that cost you users, and the failures that do not matter at all, mixed together and averaged into invisibility. Managing the mean without looking at the shape is like managing a restaurant by its average review while the kitchen occasionally serves a meal that sends someone to the hospital.

## Why the mean lies

Start with the mechanism. An aggregate pass rate is a single number computed over a set of eval tasks. That number hides at least three things that matter more than the number itself.

First, difficulty is not uniform. Your eval set has easy tasks and hard tasks, and the easy ones dominate the count. If 80 of your 100 tasks are variations on the happy path, a model that nails the happy path and fails every hard task still scores 80 percent. The score looks respectable. The hard tasks are the ones your real users actually bring you, because the easy ones are the ones they could have done themselves. An agent that passes the easy 80 percent and fails the hard 20 percent is an agent that fails exactly where it is needed.

Second, failures are not uniform either. A failure can be a slightly awkward phrasing, a missing citation, a wrong number in a table, or an action taken on the wrong record that cannot be undone. These are not the same event. The eval score treats them as the same event: one fail, one point off. A suite that fails on ten awkward phrasings and zero destructive actions scores the same as a suite that fails on zero awkward phrasings and ten destructive actions. The second suite is a liability. The score cannot tell you which one you have.

Third, users are not uniform. A failure that hits a power user on their tenth session costs you more than a failure that hits a first-time user on a throwaway query. The power user has built a workflow around your agent. The failure does not just waste their time. It breaks a habit, and habits are what retention is made of. Aggregate scores weight every task equally, which means they weight every user equally, which means they ignore the users who matter most.

The result is a predictable pattern. The eval suite keeps improving. The score climbs. And the complaints, when they arrive, do not match the score at all. They are not about the average. They are about one specific terrible experience, described in detail, by a user who sounds angrier than a 6 percent failure rate should produce. That is because they did not experience 6 percent. They experienced 100 percent failure, on the one run that mattered to them.

## The tail is the product

Think about it from the user's side. A user does not run your agent a hundred times and compute a pass rate. They run it once, for one task, and they judge the whole system on that run. If the run succeeds, they come back. If the run fails badly enough, they do not. The second run never happens, so the average never gets a chance to redeem itself.

This is the same math as reliability engineering, and the field already solved it. SRE teams do not manage average uptime. They manage error budgets, and they manage the tail. A service that is up 99.9 percent of the time but down for a full hour during the one peak hour of the year has failed its users, even though the average looks fine. The same is true for agents. A model that is right 94 percent of the time but confidently destructive 1 percent of the time is not a 94 percent agent. It is an agent with a 1 percent chance of a trust incident on every run, and trust incidents compound. One is an anecdote. Three is a reputation.

The honest way to think about it: your agent's quality is not its mean. It is the distribution of its failures, weighted by severity, concentrated on the users who use it most. Everything else is a vanity metric.

So what do you do instead? You budget for the tail, the same way you budget for tokens, latency, and retries. A budget is not a wish. It is a number with an owner and a consequence.

## Budgeting for tail failures

A tail budget has four parts. None of them is exotic. All of them are work that teams skip because the aggregate score makes them feel done.

The first part is severity grading. Every eval failure gets a severity, not just a pass or fail. I use four levels, and the definitions are deliberately blunt. A cosmetic failure changes wording, not meaning. A wrong failure gives a wrong answer the user can catch. A harmful failure gives a wrong answer the user cannot catch, or takes an action the user did not intend. A catastrophic failure takes an irreversible action on the wrong target, leaks data, or destroys work. The severity is assigned by what the failure does to the user, not by what it does to the score.

The point of grading is that it changes the arithmetic. A suite with ten cosmetic failures and zero harmful ones is a different system from a suite with one harmful failure and zero cosmetic ones, even though both score 90 percent. Once you grade, you can set a rule that actually protects users: zero catastrophic failures is a release gate, not an aspiration. A single catastrophic failure fails the suite, no matter what the pass rate says. That rule sounds harsh until you remember that one catastrophic failure in production is the user who leaves.

The second part is per-category floors. Break the eval set into categories that match the ways your agent can hurt someone: wrong data, wrong action, wrong audience, wrong tone, missing escalation. Set a minimum pass rate for each category, not just for the whole suite. A 94 percent overall score with a 60 percent score on wrong-action tasks is a system that will eventually act on the wrong record. The floor forces you to look at the category, not the average. I set the floor at the level where a failure in that category becomes a story the user tells other people. For wrong actions, that level is high.

The third part is worst-case reporting. Every eval run should report the single worst failure, by severity, with the full trace attached. Not the ten worst. The one worst. The report that lands in front of the team should lead with it, before the pass rate. The question it answers is simple: if a user hits the worst thing this agent can do, what exactly happens? If you cannot answer that question from your eval run, your eval run is not telling you what you need to know. I have seen teams discover, from a single worst-case report, that their agent could silently overwrite a shared document with a confident hallucination. The pass rate that week was 95 percent. The worst case was a data-loss incident waiting for a user.

The fourth part is production sampling with the same severity lens. Eval tasks are written by people who already know what the agent should do. Real users do not. So sample production traces, grade the failures you find there, and compare the severity distribution against the eval suite's. If production has harmful failures that the eval suite never produces, the suite has a coverage hole in exactly the place that matters. The eval that never runs is the eval that matters, and the failure that never appears in your suite is the one your users will find first.

Here is the shape of the reporting code. It is deliberately small, because the hard part is not the code. It is the decision to look at these numbers at all.

```python
def tail_report(results):
    # results: list of {task, category, passed, severity, trace_id}
    total = len(results)
    failures = [r for r in results if not r["passed"]]

    by_category = {}
    for r in results:
        by_category.setdefault(r["category"], []).append(r)

    print(f"overall pass rate: {(total - len(failures)) / total:.1%}")
    print(f"total failures: {len(failures)}")

    for category, items in sorted(by_category.items()):
        rate = sum(i["passed"] for i in items) / len(items)
        print(f"  {category}: {rate:.1%} ({len(items)} tasks)")

    worst = max(failures, key=lambda r: SEVERITY[r["severity"]])
    print(f"worst failure: {worst['severity']} in {worst['category']}")
    print(f"  task: {worst['task']}")
    print(f"  trace: {worst['trace_id']}")

    catastrophic = [r for r in failures if r["severity"] == "catastrophic"]
    if catastrophic:
        print(f"RELEASE BLOCKED: {len(catastrophic)} catastrophic failure(s)")
```

The output of this report is not a score. It is a story: here is the average, here is the worst category, here is the worst single failure, here is whether you are allowed to ship. A team that reads this report every release will make different decisions from a team that reads a single percentage.

## The trade-offs, honestly

Budgeting for the tail is expensive, and pretending otherwise would be dishonest. Severity grading takes human judgment, and human judgment takes time. Per-category floors slow releases, because a category that was fine last week can dip below the floor after a model swap. Worst-case reporting is uncomfortable, because it forces the team to look at the ugliest thing the system did instead of the prettiest average it achieved. And production sampling surfaces failures nobody wants to own.

So you have to decide how much tail risk you accept, and you have to decide it explicitly. That is what a budget is. An SRE team does not aim for zero downtime, because zero downtime costs more than the business can afford. They pick an error budget, say 0.1 percent, and they spend it deliberately. Do the same for agent quality. Pick a catastrophic-failure budget of zero, because a catastrophic failure is never worth spending. Pick a harmful-failure budget as a rate, say one in a thousand runs, and a per-category floor, and treat exceeding it as a release decision, not a shrug. The number matters less than the fact that it is written down, owned by someone, and enforced by a gate instead of a feeling.

There is a second trade-off worth naming. Chasing the tail can distort the product. If you optimize only for the worst case, you can end up with an agent so cautious it refuses to do anything useful. Every action gets a confirmation dialog. Every answer gets a hedge. The tail gets shorter and the product gets worse. The budget exists to prevent that too. A budget says: this much risk is acceptable, spend it on being useful, and stop apologizing for the rest. The goal is not a perfect agent. The goal is an agent whose worst day is survivable.

The final trade-off is the hardest one to accept. You cannot eliminate tail failures by eval alone, because the tail lives in the long run of real usage, not in your test set. What evals can do is tell you the shape of the tail you have, so you can decide whether to ship it. That is the whole job. Not a higher number. A clearer picture of the worst thing that can happen, and a decision about whether you are willing to let it happen to a user.

## The question to ask before every release

Before every release, ask one question, and answer it from evidence, not from the pass rate. What is the worst thing this version of the agent can do to a user, and how often will it happen?

If you cannot answer it, you have not evaluated the agent. You have graded it. Grading is for school. Shipping is for users, and users do not experience averages. They experience the one run they got, and if that run is the tail, they are gone, and your 94 percent will not bring them back.

What is the worst failure your eval suite has ever hidden behind a good average? The one that, if a user had hit it first, would have ended the relationship before it started?
