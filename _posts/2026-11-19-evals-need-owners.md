---
layout: post
title: "Evals Need Owners"
description: "Most teams treat their eval suite as shared infrastructure: everybody's responsibility, nobody's job. That is why eval regressions turn into tickets that rot in a backlog until someone quietly deletes the failing task. An eval without a named owner is a test nobody trusts and nobody fixes. Why eval ownership belongs to the person who owns the prompt module, what that owner actually does, and how to set it up so a regression gets a human, not a ticket queue."
date: 2026-11-19
tags: [evals, llm-evaluation, agents, ai-engineering, production-ai, ownership]
---

Most teams treat their eval suite as shared infrastructure. It belongs to the team, it lives in the repo, anyone can run it, and when it goes red, anyone can look at it. That sounds reasonable. It is also why eval regressions turn into tickets that sit in a backlog for three weeks, get deprioritized in planning, and eventually get resolved by someone deleting the failing task or loosening the threshold. The eval did not fail. The ownership model failed, and the eval was the casualty.

Here is the thesis: an eval without a named owner is a test nobody trusts and nobody fixes. It will rot. The fix is not a better dashboard or a stricter CI gate. The fix is a name. One human, attached to each eval, who decides what good means for that slice of agent behavior, who curates the golden set, and who gets paged when it regresses. A regression should reach a human, not a ticket queue.

## What most practitioners get wrong

The common mental model is that evals are infrastructure, like CI or logging. Infrastructure is shared, maintained by whoever has time, and judged by whether it is up or down. That model works for things that either work or do not work. Evals do not work that way. An eval is a judgment about quality, and quality judgments are not infrastructure. They are opinions, encoded as test cases, about what the agent should do in a specific situation. Opinions need an owner, because opinions need someone who can be argued with.

Watch what happens without one. A prompt change ships. Three evals go red. CI blocks the merge, or worse, CI is advisory and the merge goes through anyway. Someone files a ticket: "eval regression in summarization module." The ticket lands in a queue. Nobody picks it up, because picking it up means deciding whether the agent got worse or the eval is wrong, and that decision requires knowing what the summarization module is supposed to do, which golden cases are still valid, and whether the new behavior is a regression or an improvement the eval has not caught up with. The person who could answer those questions is the person who wrote the prompt, and they are busy shipping the next feature. Two weeks later the ticket is still open, the evals are still red, and the team has learned something: red evals are normal. They stop looking. The suite is now decorative.

That is the failure mode, and it is not caused by bad evals. It is caused by a missing decision-maker. A red eval is a question: did the agent get worse, or did the test get stale? That question has no default answer. It needs a human who knows the module well enough to answer it in minutes instead of a committee that answers it never.

## The ownership unit is the prompt module

The first design decision is what an owner owns. Not the whole suite, and not a single test case. The right unit is the prompt module: a coherent slice of agent behavior with a boundary you can name. The summarization prompt. The tool-selection logic. The escalation wording. The clarification questions. Each module is a product surface, and each one gets an owner.

This follows from the modular prompt idea. If your agent's behavior is composed of small, testable modules, then each module already has a natural boundary, and each boundary already has a natural owner: the person who wrote it, or the person who is responsible for that behavior now. The evals for a module belong to the module's owner, because the owner is the only person who can say, without a meeting, whether a failing case is a real regression or a golden case that expired.

Ownership is not a label in a spreadsheet. It is a set of decisions only the owner makes:

First, the owner defines what good means for the module. Not in the abstract, but as a rubric with teeth. The summarization module is good when it preserves the three facts the downstream tool needs and drops everything else. The escalation module is good when it hands off with the full context attached. Vague rubrics produce evals that pass everything and catch nothing. The owner writes the rubric, and the owner defends it when someone wants to loosen it to make CI green.

Second, the owner curates the golden set. This is the part teams skip, and it is the part that matters most. A golden set is not a pile of examples. It is a maintained collection, and maintenance means removing cases that no longer represent good behavior, adding cases for the failures you actually saw in production, and retiring cases that the model has memorized. That work requires judgment about what the module is for, which is exactly what an owner has and a ticket queue does not.

Third, the owner triages regressions. When an eval goes red, the owner answers the question within a day: agent regressed, eval stale, or golden set wrong. Three verdicts, each with a different fix. If the agent regressed, the change gets reverted or the prompt gets fixed. If the eval is stale, the eval gets updated, and the owner says why in the commit message. If the golden set is wrong, the case gets corrected, and the owner says why. The point is that the verdict is fast, public, and attached to a name. Slow verdicts are what kill eval suites.

## What ownership looks like in practice

Ownership needs to be visible in the repo, not just in someone's head. The cheapest version is a manifest: a small file that maps every eval to a person, and a CI check that fails if an eval has no owner.

```yaml
# evals/OWNERS.yaml
# Every eval module has exactly one owner. No owner, no merge.
modules:
  - name: summarization
    owner: bhaskar
    evals:
      - evals/summarization/golden_set.jsonl
      - evals/summarization/regression_cases.jsonl
    rubric: evals/summarization/rubric.md
  - name: escalation
    owner: priya
    evals:
      - evals/escalation/golden_set.jsonl
    rubric: evals/escalation/rubric.md
```

And the gate is deliberately boring. It is a script that runs in CI, reads the manifest, and fails the build if any eval file on disk has no entry, or any entry names someone who has left the team.

```python
def check_owners(manifest_path, eval_dir):
    manifest = yaml.safe_load(open(manifest_path))
    owned = {e for m in manifest["modules"] for e in m["evals"]}
    on_disk = {str(p) for p in Path(eval_dir).rglob("*.jsonl")}
    orphaned = on_disk - owned
    if orphaned:
        raise SystemExit(
            f"Orphaned evals with no owner: {sorted(orphaned)}. "
            "Add an owner to OWNERS.yaml before merging."
        )
```

That gate does one thing, and it is the thing that matters: it makes ownership a precondition of shipping, not an aspiration. An eval that nobody owns cannot land. The team will complain about the gate the first week. They will thank it the first time a regression lands on a specific person's desk instead of in a shared queue.

The second piece is routing. When an eval regresses in CI, the failure notice should go to the owner, by name, with the failing cases attached. Not to a channel where everyone sees it and nobody acts. Not to a ticket that gets groomed next sprint. To the owner, directly, with the trace IDs and the diff between the old output and the new one. The owner is the person who can read that diff and know, in minutes, whether the agent got worse or the world moved on.

The third piece is a time budget, and this is the piece most teams refuse to admit they need. Owning evals is real work. Curating a golden set, triaging regressions, updating a rubric: that is a few hours a month per module, and it does not happen if the owner is also expected to ship features at full speed. If you assign ownership without allocating time, you have assigned a second job and pretended it is free. Budget it openly. An owner who is given four hours a month for eval work will do it. An owner who is told to fit it in around everything else will not, and the suite will rot on exactly the same schedule as before, except now you have a name to blame, which is worse.

## The trade-offs, honestly

Ownership has real costs, and the honest version of this argument names them.

The first cost is the bottleneck. When one person owns a module's evals, that person becomes the gatekeeper for changes to that module. A prompt edit that used to ship in an afternoon now waits for the owner to review the eval results. That friction is real, and it is the price of the system. The counter is that the alternative is not frictionless shipping. The alternative is shipping without knowing whether you broke something, and discovering it from users. The owner's review is slower than no review, and faster than an incident.

The second cost is the bus factor. If the owner leaves, the module is orphaned, and you are back where you started. The mitigation is a co-owner, not a committee. Every module gets a primary owner and a secondary who can answer the regression question if the primary is away. Two people is a handoff. Five people is a queue.

The third cost is that ownership concentrates the least glamorous work on the people who care most. The engineers who write good evals are the engineers who get asked to own more evals, and the reward for doing the job well is more of the job. That is a management problem, not an argument against ownership. Rotate ownership on a schedule, recognize it in reviews, and treat eval ownership as a seniority signal, not a chore handed to whoever volunteers. If nobody wants to own the evals, that tells you something about how the team values them, and the fix is to value them, not to spread them thinner.

There is also a genuine tension that has no clean resolution. Strict ownership can make teams territorial. An owner can become defensive about their module, resist changes from other engineers, and treat the golden set as their personal taste instead of a shared standard. The answer is not to remove the owner. It is to make the rubric public and the golden set reviewable, so the owner's judgment is checkable. Ownership means you decide, and you explain the decision where everyone can see it. It does not mean you decide in private.

## The contrarian part

Here is the stance I will defend. Shared ownership of evals is not ownership. It is a polite way of saying nobody is responsible, and the eval suite will be maintained at exactly the level nobody is responsible for, which is zero. Every team that tells me "we all own the evals" has a suite with red tests nobody has looked at, golden cases from a product that no longer exists, and a threshold that was loosened twice to stop the noise. I have never seen a shared-ownership suite stay healthy for a year. I have seen named-owner suites stay healthy for years, because a named owner has a reputation attached to the module, and reputations are maintained.

This is unpopular because it sounds like bureaucracy, and engineers hate bureaucracy. But a name in a manifest is not bureaucracy. It is the smallest possible amount of structure that prevents the most common failure mode in eval practice, which is not a bad test, but a good test that nobody looks at. The teams that resist ownership are usually the teams that have already learned to live with red evals, and they have mistaken tolerance for resilience.

The other unpopular part: your eval suite is only as good as its worst-owned module. You can have a rigorous golden set for the summarization module and a rotting one for escalation, and the suite as a whole is only trustworthy where someone is watching. Coverage numbers lie in exactly the same way aggregate eval scores lie. They hide the tail. The tail is the module nobody owns, and it is the module that will fail in production.

None of this means evals are a burden to be managed. It means they are a product, with customers, and the customers are the engineers who need to trust the suite before they ship. A product with no owner gets no roadmap, no maintenance, and no one to call when it breaks. Your evals are no different.

## What to do on Monday

Open your eval directory and count the evals with no named owner. If the answer is all of them, you have your answer about why regressions feel so slow to resolve.

Then pick one module, the most important one, the one whose failure would hurt most. Name an owner, by name, in a file the team can see. Give them the rubric, the golden set, and four hours a month. Wire the CI gate so no new eval lands without an owner. Route the next regression to the owner directly, not to a queue, and watch how fast the verdict comes back.

The sharp version: your evals do not need more tests. They need a name attached to each one, and a human who answers when it goes red.

Which eval in your suite has been red the longest, and whose name would you put next to it?
