---
layout: post
title: "The Verification Tax: Why Every Agent Feature Should Be Priced in User Effort"
description: "The real cost of an agent feature is not tokens or latency. It is the effort a user must spend checking the work. If verifying the output costs more than doing the task yourself, the agent has negative value no matter how good it is. How to design so checking stays cheaper than doing."
date: 2026-11-27
tags: [agents, trust, production-ai, ai-engineering, user-experience, evals]
---

Most agent teams price their features in tokens and latency. They can tell you exactly what a run costs in API spend and exactly how long it takes to return. They cannot tell you what it costs the user to check whether the run was right. That missing number is the one that decides whether the agent gets used twice.

Here is the thesis: every agent feature has a verification tax, the effort a user must spend to confirm the work is correct, and that tax is the real price of the feature. Tokens and latency are costs the builder pays. Verification is a cost the user pays, in attention, in time, in the mental work of reading something carefully enough to trust it. If checking the work costs more than doing the task yourself, the agent has negative value, no matter how accurate it is, no matter how fast it is, no matter how cheap the tokens are. A feature that saves ten minutes of doing and costs twelve minutes of checking is not a feature. It is a chore with better marketing.

Most practitioners get this wrong because they measure the wrong side of the transaction. They measure what the agent did. They do not measure what the user had to do after the agent finished. The demo shows the agent completing a task in thirty seconds. The demo never shows the user spending twenty minutes reading the output, cross-checking the numbers, and wondering whether the confident tone is justified. The demo is honest about the thirty seconds and silent about the twenty minutes. Production is where the twenty minutes live.

## The math nobody writes down

The value of an agent task is not time saved. It is time saved minus verification time minus the expected cost of errors that slip through. Write it plainly:

value = (time to do it yourself) - (time to verify the agent) - (probability of an undetected error x cost of that error)

The first term is what every agent pitch celebrates. The second term is what every agent deployment discovers. The third term is what every agent incident report is about.

The second term is the dangerous one, because it is invisible until it is not. A user who trusts the agent skips verification, and the third term quietly grows. A user who does not trust the agent verifies everything, and the second term eats the first term whole. There is a narrow band in the middle where the agent is genuinely useful: the user verifies cheaply, catches the real errors, and still comes out ahead. Most agent features are not designed to live in that band. They are designed as if verification were free, and then the team is surprised when users either blindly accept everything or stop using the agent entirely. Both behaviors are rational responses to the same pricing problem.

Notice what this math implies about accuracy. A more accurate agent does not automatically create more value, because accuracy only shrinks the third term. If the second term is large, accuracy is irrelevant. An agent that is right 99 percent of the time but produces output that takes an hour to verify is worth less than an agent that is right 90 percent of the time and produces output that takes two minutes to check, provided the 10 percent failure is cheap to catch. The industry obsesses over the 99 and ignores the hour. That is backwards.

## Why verification is so expensive

Verification is expensive for four structural reasons, and none of them are solved by a better model.

First, fluent output reads as correct. A well-written paragraph, a clean-looking code diff, a tidy table of numbers: all of them feel true on first reading. The model's fluency is a verification hazard, not just a feature, because it removes the friction that would normally make a reader slow down. Human writing has tells. Hesitation, uneven quality, awkward phrasing: these are signals that something might be wrong, and they prompt closer reading. Model output has no tells. A wrong answer and a right answer are equally smooth. The user has to supply the skepticism that the text itself does not provide, and supplying skepticism is work.

Second, the reasoning is invisible. The user sees the conclusion, not the path. When an agent summarizes a document, the user sees the summary, not which passages it relied on, which it ignored, or where it guessed. To verify the summary, the user must reconstruct the path the agent took, which means doing much of the original work. The agent saved the user the effort of writing. It did not save the user the effort of reading.

Third, outputs are shaped for the agent's convenience, not the verifier's. A 200-line code change is easy for the model to produce and hard for a human to review, because the human has to hold the whole change in their head and reason about its interactions. A long report is easy for the model to generate and hard to check, because the claims are buried in prose and the evidence is not attached to them. The output format optimizes for generation. Verification wants the opposite format: claims paired with evidence, changes broken into reviewable units, the riskiest parts surfaced first.

Fourth, verification does not scale with the agent's speed. The agent gets faster with every model release. The user does not get faster at reading. An agent that returns in five seconds and takes twenty minutes to verify is a machine for generating verification debt. Speed without checkability is not progress. It is a backlog.

## What the tax looks like in practice

Take code generation. An agent writes a 200-line function. To verify it, a developer must read the diff, understand the intent, check the edge cases, and reason about whether the tests actually cover the change. That is the same work as writing the function, minus the typing. The typing was never the expensive part. The expensive part was the thinking, and verification is the thinking, done under worse conditions, because the developer is reading someone else's reasoning instead of their own. The teams that get the most value from coding agents are not the ones whose agents write the most code. They are the ones whose agents write code in small, reviewable units with the reasoning attached.

Take data analysis. An agent produces a report with a conclusion and a table of numbers. Verifying the conclusion means verifying the numbers, which means verifying the query, the filters, the joins, and the aggregation. The user cannot verify the conclusion without verifying the pipeline, and the pipeline is invisible. The honest verification cost is the cost of redoing the analysis. So the user either redoes it, which makes the agent pointless, or trusts it, which makes the agent dangerous. The fix is to make the pipeline visible: the query, the filters, the row counts at each step, the assumptions.

Take multi-step actions. An agent books, files, updates, and sends. Verifying the whole run means reconstructing the sequence and checking that each step's inputs were the previous step's correct outputs. A single wrong value early in the chain corrupts everything after it, and the corruption is invisible unless the user traces the chain. This is why the receipt idea matters, and why I wrote about it earlier: an outcome receipt lists what the agent did, in order, with the inputs and the results, so the user can check the run in minutes instead of reconstructing it in an hour.

## Designing so checking stays cheaper than doing

If verification is the price, then the design goal is to make verification cheap. Four principles, in order of leverage.

First, make outputs checkable by construction. Pair every claim with its evidence. A summary should cite the passages it draws from. A code change should come with the test that proves it and the reasoning for the approach. A number should come with the query that produced it. The point is not to add documentation for its own sake. The point is to move verification from reconstruction to inspection. Reconstruction means doing the work again. Inspection means looking at the evidence and judging it. Inspection is an order of magnitude cheaper, and it is the only kind of verification that scales.

Second, surface the riskiest parts first. Most of an output is routine. A small part is load-bearing: the assumption the conclusion rests on, the edge case the code handles differently, the filter that excludes half the data. The agent should identify those parts and put them in front of the user. A good output format has a "check this" section: the three things most likely to be wrong, with the evidence for each. This is the opposite of the confident, seamless output agents are trained to produce. It is deliberately lumpy, and the lumpiness is the point.

Third, verify in slices, not in bulk. A single massive output is a single massive verification task, and humans are bad at sustained careful reading. The same work delivered in small, verifiable units, each with its own evidence and its own check, is dramatically cheaper to verify. This is the same argument as small pull requests, applied to agent output. The unit of work and the unit of verification should be the same size.

Fourth, price features in verification effort before you ship them. Before adding a capability, ask: how will the user check this? If the honest answer is "they will have to redo the work" or "they probably will not check it at all," the feature is not ready, no matter how impressive the demo. A feature whose verification cost exceeds its time savings should not ship. A feature whose verification cost is unknown should not ship either, because unknown verification cost is just unmeasured tax.

Here is what that design review looks like as a concrete check, the kind of thing you can put in a pull request template for agent features:

```python
# Verification budget: every agent feature must answer these
# before it ships. If any answer is "the user redoes the work"
# or "the user probably won't check", the feature is not ready.

VERIFICATION_CHECKLIST = {
    "evidence_attached": "Can the user see the sources for each claim?",
    "riskiest_first": "Are the load-bearing assumptions surfaced explicitly?",
    "slice_size": "Is the output broken into units a human can check in minutes?",
    "spot_check": "Can the user verify the run by checking 3 items, not everything?",
    "failure_visible": "If the agent is wrong, does the output make it visible?",
}

def verification_review(feature):
    gaps = [k for k, q in VERIFICATION_CHECKLIST.items()
            if not feature.get(k)]
    return gaps  # empty means the feature is shippable
```

The checklist is deliberately boring. It is a gate, not a philosophy. The value is that it forces the conversation before the feature ships, when the verification design is still cheap to change, instead of after users have already learned to either blindly accept or quietly abandon the agent.

## The objections, honestly

Three objections come up every time, and two of them are partly right.

The first is that adding evidence and receipts makes outputs longer, which costs tokens and makes the agent slower. True. Verification artifacts are not free. But the tokens are the builder's cost, and the verification time is the user's cost, and the user's time is the scarcer resource. Spending tokens to save user attention is a good trade in almost every production setting, because token prices fall and attention does not. The right question is not whether receipts cost tokens. It is whether the tokens buy more verification savings than they cost. They almost always do.

The second is that showing uncertainty and risk erodes trust. If the agent keeps flagging its own uncertain parts, users will stop trusting it. This is backwards. Users do not trust agents that are always confident. They trust agents whose confidence is calibrated, because calibration is evidence that the agent knows the difference between solid ground and thin ice. An agent that says "I am confident about these three things and unsure about this one" is more trustworthy than an agent that says "I am confident about everything," because the second agent is lying some of the time and the user knows it.

The third is that some tasks cannot be made cheap to verify. A legal analysis, a complex financial model, a subtle code change: these take real expertise to check, and no output format removes that. This objection is correct, and it is the most important one, because it sets the boundary of what agents should do. If a task cannot be verified cheaply by its intended user, the agent should not do that task autonomously. It should do it with the user in the loop, or in slices the user can check, or not at all. The verification tax is not just a design constraint. It is a scope constraint. The tasks worth automating are the ones where checking stays cheaper than doing. Everything else is a demo waiting for an incident.

## Where to start

If you run an agent in production, start by measuring the tax you are already charging. Pick your most-used feature and time five users verifying its output. Not the time to run it. The time to check it, from the moment the output arrives to the moment the user is willing to act on it. Compare that to the time the task took before the agent existed. If verification costs more than doing, you have a feature with negative value, and the fix is not a better model. The fix is evidence, risk surfacing, and smaller slices.

Then add the verification review to your feature process, the checklist above or your own version of it. Price every new capability in user verification effort, alongside tokens and latency.

The agents that win in production will not be the ones that generate the most. They will be the ones whose output is the cheapest to trust. Build for the verifier, not just the generator, because the verifier is the user, and the user is the one paying the tax.

What is the most expensive thing your users have to verify, and what would make it cheap?
