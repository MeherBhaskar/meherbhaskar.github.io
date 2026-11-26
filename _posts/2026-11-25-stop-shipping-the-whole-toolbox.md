---
layout: post
title: "Stop Shipping the Whole Toolbox"
description: "Every tool you hand an agent is a suggestion, a temptation, and a failure mode, whether the agent ever calls it or not. Tool availability shapes behavior before a single call is made. How to load tools lazily, scope them per task, and stop paying for a toolbox your agent never needed."
date: 2026-11-25
tags: [agents, tool-use, multi-agent, production-ai, ai-engineering, latency]
---

Most agent teams treat the tool list like a menu. The more tools, the more capable the agent, so they register everything the system can possibly do and hand the whole toolbox to the model on every turn. The reasoning feels obvious. It is also wrong in a specific, measurable way: every tool you offer changes what the agent does, even when the agent never calls it.

Here is the thesis: tool availability is a behavior-shaping decision, not a capability decision. A tool the agent can see but does not need is not harmless. It costs tokens on every turn, it competes for the model's attention, it creates failure modes that did not exist before it was registered, and it invites the model to solve problems with the wrong instrument. The fix is not better prompting. The fix is to give each task the smallest set of tools that can actually do it, loaded only when the task needs them.

Most practitioners get this wrong because they think about tools the way they think about libraries. In ordinary software, importing a library you never call costs almost nothing. The function sits there, inert, until someone invokes it. An agent's tool list does not work that way. The tool definitions are part of the prompt. The model reads every one of them, on every turn, before it decides anything. A tool you never call still occupies context, still competes with the tools that matter, and still shapes the model's idea of what the task is about. Importing a library is free. Describing a tool to a model is a tax you pay in tokens, in attention, and in behavior, on every single turn of every single run.

## The tool list is a prompt, not a registry

When an agent runs, the model receives a system prompt, the conversation history, and a list of tool definitions. Each definition has a name, a description, and a schema for its parameters. A typical tool definition runs 100 to 300 tokens. Forty tools is 4,000 to 12,000 tokens of definitions, injected before the model has seen a single word of the user's actual request, and re-sent on every turn. On a multi-agent system, every sub-agent pays the same tax with its own copy of the list.

The token cost is the least interesting part. The interesting part is what those definitions do to the model's decision making. A language model does not select tools by consulting a clean mental index. It reads the descriptions, pattern-matches them against the task, and picks the one that seems closest. The more tools in the list, the more near-misses exist. Two tools that overlap by 80 percent will fight each other on every task where either one could plausibly apply, and the pick is essentially a coin flip driven by wording and ordering.

This shows up in production traces as a recognizable pattern: the agent calls a tool that works, but it is the wrong tool for the job. It queries the search API when a direct lookup would have been exact. It calls the delete endpoint when the archive endpoint was the right move, because delete was listed first and its description sounded more decisive. The task eventually completes, so nobody investigates. But the run cost more, took longer, and carried more risk than it needed to, and the root cause was not the model. It was the toolbox.

This is why adding tools to fix a capability gap so often backfires. A team notices the agent cannot do X, so they register a tool for X. The agent can now do X, but the tool also changes the agent's behavior on every task where X is irrelevant, because the model now considers X-shaped solutions everywhere. The tool you added for one edge case becomes a standing temptation on every run. The toolbox grows, the behavior drifts, and nobody can point at a single change that caused it, because the cause was the accumulation itself.

## What a big toolbox actually costs

First, token spend. A run with 12 turns and a 6,000-token tool list pays 72,000 tokens just to keep reminding the model what tools exist, before the conversation history, before the tool results, before the actual work. Most of those tokens describe tools the run never touches.

Second, selection errors. Every additional tool is another chance for the model to pick wrong, and the error rate grows fastest exactly where tools overlap, which is exactly where your team added tools to cover edge cases. The paradox is sharp: the more tools you add to cover more cases, the worse the model gets at picking the right one for any given case.

Third, failure surface. Every registered tool is a thing the agent can call incorrectly, and a thing whose side effects the agent has to reason about. A tool with write access that the task does not need is not a dormant capability. It is a live risk on every turn, because the model can call it by mistake, and the mistake will be a real write. The permission model of your agent is, in practice, the tool list. If a tool is in the list, the agent can use it. If the agent can use it, it eventually will, on a task where it should not have.

Fourth, debugging. With a small, task-scoped tool set, the trace is legible: the agent had five tools, it called three, and here is the reasoning. With a forty-tool list, the trace is a haystack. The team cannot tell whether the failure was a model error, a description error, or a selection error caused by two overlapping tools. The investigation takes longer, the fix is less certain, and the same failure recurs because the root cause was never isolated.

## Lazy loading: tools as a second decision

The fix starts with a simple idea: do not give the agent all its tools up front. Give it the tools for the task it is doing now, and load more only when the task changes. The pattern has three layers, and they compose.

The first layer is per-task tool subsets. Before the agent starts, a small routing step decides which tools this task needs: a classifier, a set of rules, or a cheap model call. The decision is explicit and cheap, and it happens once per task instead of being re-litigated by the main model on every turn. A task about summarizing a document gets read tools and a summarization tool. It does not get the deployment tool, the billing tool, or the database migration tool. Those tools do not exist as far as the model is concerned, which means they cannot be called by mistake, cannot compete for attention, and cannot shape the plan.

The second layer is staged loading inside a task. The investigation phase needs search and read tools. The action phase needs write tools. Loading the write tools only after the investigation is complete keeps the tool list small during the phase where the model is reasoning most, and it creates a natural checkpoint: the agent cannot take an irreversible action before it has finished looking. The phase boundary becomes a safety boundary, enforced by what the model can see rather than by what the prompt asks it to remember.

The third layer is discovery on demand. For tools the agent might need but probably will not, do not register them at all. Register a single search tool that can find and load other tools by description. When the agent hits a task it cannot complete with its current set, it searches for a tool, loads it, and continues. You do not carry every tool you own to every job. You carry the ones the job needs, and you go back to the truck when you need something else.

Here is what the per-task subsetting looks like in practice. It is deliberately small, because the hard part is the decision about which tools belong, not the machinery.

```python
# Task profiles: the tools each kind of task is allowed to see.
# This is the whole policy. Review it like a permissions file,
# because that is what it is.
TASK_PROFILES = {
    "summarize": ["search_docs", "read_file"],
    "fix_bug": ["search_docs", "read_file", "write_file", "run_tests"],
    "deploy_change": ["read_file", "run_tests", "deploy"],
    "answer_question": ["search_docs", "query_db"],
}

IRREVERSIBLE = {"deploy", "delete_record", "send_email"}

def tools_for_task(task_type, phase="investigate"):
    allowed = TASK_PROFILES[task_type]
    if phase == "investigate":
        # Irreversible tools are invisible until the act phase.
        allowed = [t for t in allowed if t not in IRREVERSIBLE]
    return allowed
```

The profile table is the artifact that matters. It says, in one place, which tools each task type can see. When someone wants to add a tool to a task, they edit the profile, and the change is visible, reviewable, and reversible. Compare that with the usual approach, where the tool list is assembled in code somewhere, grows by accretion, and nobody can say why a given task has access to a given tool. The profile table turns an implicit accumulation into an explicit decision.

And the phase gate matters. The deploy tool is excluded during the investigate phase and only appears when the phase flips to act. The model cannot call deploy while it is still investigating, not because the prompt told it not to, but because deploy is not in its world yet. That is the difference between a rule the model might follow and a constraint the model cannot violate.

## What tool availability does before the first call

The deepest argument for lazy loading is not cost or safety. It is that the tool list shapes the model's thinking from the first token of the first turn, before any tool is called. When the model receives a task with forty tools attached, it has already read forty descriptions before it writes a single word of its plan. Those descriptions prime it. They suggest approaches, imply capabilities, and anchor the model's sense of what a good solution looks like. A tool list heavy on data-fetching tools nudges the model toward data-fetching solutions. The priming is invisible, because it happens before the trace shows any reasoning. You cannot see it in the log. You can only see its consequences, in the shape of the plans the agent produces.

This is why the strongest version of this idea is not "fewer tools" but "the right tools, at the right time." A small, well-chosen tool set does not just reduce errors. It focuses the model. With five tools, the model's plan is constrained to five verbs, and the constraint is productive: the model has to think in terms of what it can actually do, and the plan it produces is executable. With forty tools, the plan is a wish list, and the model spends its reasoning on choosing among options instead of solving the problem. Your agent deserves a small, task-appropriate set. The whole toolbox should exist, but it should live in the truck, not on the counter.

## The objections, honestly

Three objections come up every time. The routing step can be wrong, and then the agent lacks a tool it needs. Make that failure visible and recoverable: the agent says so, the system escalates by loading the next tool set or falling back to the full list, and the miss is logged so the profile gets fixed. A routing miss that is logged and corrected beats a selection error that is invisible. Staged loading adds latency, but it replaces the tokens spent describing forty tools on every turn and the extra turns spent recovering from wrong tool choices. And some tasks genuinely need many tools. That is not an argument against lazy loading. It is an argument for profiles that are honest about it. The question is never "few tools or many tools." The question is always "which tools, for this task, right now."

## Where to start

If you are running an agent in production with a single global tool list, start by measuring. Log, for every run, which tools were registered and which were actually called. The gap between those two numbers is the size of the problem. Most teams find that any given run uses a third or less of the tools it was given. The rest is pure tax. Then write the profile table for your most common task types, and let everything else fall back to the current behavior. Then add the phase gate for irreversible tools, because the model cannot misuse a tool it cannot see. Then add the discovery tool for the long tail, and log every discovery, because the log is the evidence you need to grow the profiles honestly instead of by guesswork. And review the profiles on a schedule. A profile that was right three months ago may be wrong now.

Stop shipping the whole toolbox. Give each task the tools it needs, load them when the task needs them, and keep the rest in the truck. Your agent will be cheaper to run, easier to debug, harder to misuse, and, most importantly, better at the task in front of it, because the task in front of it is the only thing it can see.

What is in your agent's tool list right now that no run has ever called?
