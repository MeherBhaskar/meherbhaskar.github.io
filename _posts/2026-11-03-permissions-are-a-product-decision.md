---
layout: post
title: "Permissions Are a Product Decision"
description: "Most teams launch agents with broad tool scopes and plan to tighten them later. Later never comes, because broad permissions quietly become the product: the agent's reach is its behavior. Treat scopes as a product surface, ratchet authority down on evidence, and put irreversible actions behind approval, or your agent's blast radius is whatever your first draft allowed."
date: 2026-11-03
tags: [agents, permissions, security, tool-design, production]
---

Most practitioners get agent permissions wrong in one specific way. They treat scopes as an infrastructure detail, something the platform team sorts out after the agent works. The demo needs the agent to actually do things, so it gets broad access: read and write, all the tools, every record it might plausibly need. Somebody writes "tighten scopes before launch" on a ticket. Launch arrives, the ticket is still open, and the agent ships with the keys to the building.

That is not a housekeeping failure. It is a product decision made by default, and it is the wrong one. Your agent's permissions are not a layer underneath the product. They are the product, or at least the part of the product that decides what a bad run can touch, what a confused run can break, and what a manipulated run can steal. Every scope you grant is a promise to the user about what the agent is allowed to do on their behalf. Most teams make that promise without ever reading it.

Here is the thesis: permissions are a product decision, and the right default is not "grant what the agent might need." It is "grant what this task provably needs, and expand only on evidence." Broad scopes are not generosity toward the agent. They are debt, and the interest is paid in blast radius.

## A prompt is not a permission

The first confusion to clear up is the one that makes every other mistake possible. A system prompt that says "only refund orders under a threshold" or "never delete records" is not a permission. It is a suggestion, written in the same flat context as everything else the agent reads, including tool outputs that may be hostile, mistaken, or just weird. The model weighs it against recency, specificity, and the user's latest instruction, and it loses those fights more often than teams admit.

A permission lives somewhere the model cannot argue with: the tool layer. When the agent calls a tool, something outside the model checks whether this caller, in this run, for this task, is allowed to do this thing to this record. If the answer is no, the call does not happen, no matter how confidently the model requested it. That distinction is the whole game. Prompts shape intent. Permissions bound effect. Confusing the two is how you end up with an agent that politely explains its safety policy while executing the exact action the policy forbids.

Consider a support agent, a completely ordinary one. It reads tickets, checks order status, issues refunds, and updates shipping addresses. Give it one broad "orders" scope and you have given it four different powers with four different risk profiles, bundled under one name. Reading an order is reversible and low stakes. Issuing a refund moves money. Changing a shipping address redirects goods. Deleting a record destroys evidence. The agent's job description treats these as one capability. Your permission model must not.

The failure mode is not exotic. It does not require a sophisticated attacker. It requires an agent that misreads a ticket, a tool result that contains a pasted instruction from a third party, or a user who phrases a request just ambiguously enough that the agent fills in the wrong details. With narrow scopes, each of those is a failed call and a log entry. With broad scopes, each is a completed action that someone has to unwind.

## Broad scopes become the product

Here is the part teams underestimate: once an agent ships with broad permissions, those permissions shape behavior in ways no prompt edit can undo. The agent learns, in the loose sense that its traces and evals reflect, that it can do things. Workflows get built around the broad access. Users discover that the agent can fix a thing directly instead of drafting a fix for review, and they start expecting the direct fix. Support teams stop checking the agent's work because it has usually been right. The broad scope stops being a temporary shortcut and becomes the assumed contract.

Then comes the tightening attempt, months later, and it fails for a reason nobody predicted: narrowing a scope is a breaking change to the product. Something the agent used to do, it now refuses to do, or routes to approval. Users complain. Evals that passed before now fail, not because the agent got worse, but because the evals were written against the broad behavior. The team concludes that least privilege is impractical and restores the broad scope. The debt is now permanent, defended by its own dependents.

This is why "tighten later" is not a plan. It is a decision to let the broad scope become load bearing. The time to set the boundary is before anyone builds on top of crossing it.

## Ratchet authority down, on evidence

The alternative is a ratchet, and it runs in one direction only: start narrow, expand when a specific task proves it needs more, and never expand on a hypothetical. The ratchet has a discipline to it that is worth spelling out, because "least privilege" as a slogan is too vague to implement.

First, inventory the tools by effect, not by name. For each tool, write down what it changes in the world: money moved, records created or destroyed, messages sent, access granted. A tool that reads is not in the same class as a tool that writes, and a tool that writes a draft is not in the same class as a tool that sends. If your inventory lists tools by their API names, you have an inventory of endpoints, not of risk. Classify by consequence.

Second, split scopes along the lines the risk actually follows. Read versus write is the first split. Then: own records versus other people's records, draft versus send, reversible versus irreversible, single record versus bulk. An agent that can refund one order is a different product from an agent that can refund a thousand in a loop, and the scope should say so. Bulk operations deserve their own scope, their own approval, and their own audit trail, because the blast radius of a loop is the blast radius of one call times however many iterations the agent decides to run.

Third, make elevation time boxed and task scoped. An agent that needs write access for one migration, one cleanup, or one escalated ticket should get that access for that task, and then lose it. Standing broad access is the thing that turns a single compromised or confused run into a campaign. Temporary elevation is slightly annoying to implement and enormously cheaper than explaining a standing permission after the fact.

A sketch of what this looks like at the tool layer:

```python
def call_tool(agent, tool, args):
    grant = current_grant(agent, task_id)
    if not grant.allows(tool, args):
        return refused(tool, reason="scope", grant=grant.id)
    if tool.effect == "irreversible":
        approval = request_approval(agent, tool, args)
        if not approval.granted:
            return refused(tool, reason="approval-denied")
    return execute(tool, args)
```

Nothing in that sketch is clever, and that is the point. The check is boring, deterministic, and outside the model. The model can be confused, manipulated, or just wrong, and the worst outcome is a refused call. Boring is the security property.

Fourth, put irreversible actions behind a human, and mean it. Not behind a confirmation prompt the agent can answer for the user. Behind an actual approval step, in a channel the agent does not control, with the exact action and its target shown. The test is simple: could the agent, acting alone, complete this action end to end? If yes, you do not have an approval gate. You have a speed bump the agent can drive over while quoting your policy back to you.

## The honest trade-offs

None of this is free, and pretending otherwise is how teams abandon it. Narrow scopes create friction in three places, and you should budget for all of them.

Approval fatigue is real. If every slightly consequential action pings a human, humans stop reading the pings, and your approval gate becomes a rubber stamp with extra latency. The fix is not fewer approvals. It is fewer actions that need them, by designing workflows where the agent drafts and the human sends, where reversible steps proceed and irreversible steps wait, and where routine actions earn standing approval only after a track record, scoped tightly to the routine case. Approval should be scarce enough to stay meaningful.

Velocity takes a hit at the start. Writing the inventory, splitting the scopes, and building the check takes time that broad access does not. The honest reply is that broad access also takes time, it just takes it later, in incident response, in unwinding bad runs, and in the migration that never happens because too much depends on the broad scope. You pay either way. Narrow scopes let you choose when.

And debugging gets harder in one narrow sense: a refused call looks like an agent failure until you read the log. Teams that do not log refusals with the scope, the task, and the requested arguments will misdiagnose permission denials as model errors and "fix" them by widening the scope. Log the refusal as a first class event. When a refusal turns out to be wrong, that log is the evidence that justifies expanding the scope, which is exactly how the ratchet is supposed to work: expansion on evidence, not on frustration.

## What to do on Monday

If you own an agent in production, do not start with a rewrite. Start with the inventory. List every tool the agent can call, classify each by effect, and mark the irreversible ones. You will find at least one scope that bundles a read with a write, or a single-record action with a bulk one, or a draft with a send. Split that one first. It is the highest return change available, and it requires no model change at all.

Then find the broadest scope and ask the question that should have been asked at launch: which task, exactly, needs all of this? If no single task needs all of it, the scope is not a requirement. It is a habit. Replace it with per-task grants and watch which tasks actually request elevation. The elevation log becomes your real requirements document, written by the work itself instead of by speculation at design time.

The deeper point is about who decides what an agent is. Right now, in most teams, the answer is: whoever wrote the first tool configuration, in a hurry, before launch. That is not a decision process. Permissions deserve the same product attention as the user interface, because they are the part of the interface that decides what happens when things go wrong. A scope is a statement about trust: this agent, doing this task, may touch this much of the world, and no more. Write that statement deliberately, review it like a product spec, and ratchet it only when the work proves it should move.

What is the broadest scope your agent currently holds, and which single task would break first if you narrowed it? That answer is your roadmap.
