---
layout: post
title: "Kill the Mega-Prompt: Compose Agent Behavior from Small, Testable Modules"
description: "Most agent teams manage their system prompt like a document: append a rule every time something breaks. The result is a wall of instructions nobody can reason about. Treat the prompt as a program instead: small modules, each with one job and at least one test, composed in a fixed order. Here is how that changes debugging, review, and safe iteration."
date: 2026-10-22
tags: [agents, prompts, prompt-engineering, testing, production]
---

Most practitioners get system prompts wrong in the same way. They treat the prompt as a document. Something breaks in production, someone appends a rule. Another edge case appears, someone appends a paragraph. Six months later the system prompt is thousands of tokens long, nobody has read all of it in one sitting, and nobody dares delete a line, because nobody remembers which line is load bearing and which one was a workaround for a bug fixed three releases ago.

Here is the thesis: a system prompt is not a document. It is a program, and programs that grow past a certain size get decomposed into modules with tests, or they become unmaintainable. Agent behavior should be composed from small prompt modules, each with one job, one owner, and at least one test that proves it does that job. The mega-prompt is not a stage every team passes through. It is a failure mode, and the longer you live with it, the more expensive every change becomes.

## Why mega-prompts fail: four mechanisms

The failure is not that long prompts are "bad." It is that a single undifferentiated block of instructions has four specific properties that make it unmaintainable, and each one bites independently.

First, instruction following is not a database lookup. A model does not apply every instruction with equal weight. Instructions compete. Position matters, phrasing strength matters, repetition matters. When two rules conflict, and in a long prompt two rules always eventually conflict, the model resolves the conflict by something like recency or emphasis, not by your intent. "Be concise" in paragraph two and "explain your reasoning thoroughly" in paragraph fourteen do not average out into "moderately detailed." One of them wins, and which one wins can change with the model version, the conversation length, or the user's phrasing. A mega-prompt is a bundle of unresolved conflicts waiting for the wrong input to resolve them badly.

Second, instructions interact. A rule about tool use changes how a rule about tone plays out, because tool calls interrupt the response the tone rule governs. A rule about asking clarifying questions changes how a rule about completing tasks autonomously plays out. In a flat document, these interactions are invisible. You cannot see them by reading, because reading is linear and the interaction is combinatorial. Every edit is a gamble against every other paragraph, and the only way to find out you lost is a production incident.

Third, a mega-prompt cannot be tested. Not really. You can run your eval suite against the whole thing and watch the aggregate score move, but when the score moves you cannot say why. Was it the new paragraph, or the interaction between the new paragraph and the old one about formatting? A test that covers everything tests nothing in particular. This is the same reason engineers do not test a whole application with only end-to-end tests: when one fails, you have a symptom and no diagnosis.

Fourth, a mega-prompt has no ownership. A document that everyone appends to belongs to no one. Rules accumulate because adding is safe and deleting is scary. I have seen prompts carrying rules for tools that no longer exist, rules written for a model version retired a year ago, and rules that contradict each other because two different people fixed the same incident six months apart. Dead rules are not harmless. They consume attention, they interact with live rules, and they teach every new team member that the prompt is a place where text goes to be forgotten.

## What counts as a module

A module is a small block of instructions with a single responsibility, a name, a version, and a test. The boundaries matter more than the size. A good split follows the jobs the agent actually has, not the sections of a document. For a typical production agent, the modules look something like this:

- Identity and role: what the agent is, who it serves, what it never claims to be.
- Task contract: what counts as a completed task, what the output format is, what must never be left ambiguous.
- Tool policy: which tools exist, when each is appropriate, and what is explicitly out of scope for each. (The negative clause, what a tool is NOT for, belongs here.)
- Verification policy: what the agent checks before it answers, and what it does when a check fails.
- Tone and style: how it writes, how long its answers run, how it handles uncertainty.
- Guardrails: what it refuses, what it escalates, and the exact escalation path.
- Recovery: what it does when a tool fails, when a result looks wrong, or when it is stuck.

Each module should be small enough that one person can hold it in their head and explain why every sentence is there. If a module needs a paragraph justifying itself, it is probably two modules. If you cannot say what a module owns in one sentence, its boundary is wrong.

One more rule: examples are modules too. Few-shot examples are the most powerful and least reviewed part of most prompts. They drift silently, they encode behaviors nobody wrote down as rules, and they rot when the product changes. Version them separately from the rules, and test them the way you test rules: change an example, watch what moves.

## Composition: order is a design decision

Modules are assembled in a fixed order, and that order is itself a decision worth writing down. Later modules should not silently override earlier ones by accident, so pick a precedence convention and enforce it. The one I use: identity first, task contract second, tool and verification policy next, guardrails last, because guardrails are the rules that must win conflicts. When a conflict appears, and it will, the resolution is "the later module wins" or "guardrails always win," stated once, instead of being re-litigated in every incident review.

Composition also gives you something a flat document never can: variants. A support agent and an internal tooling agent can share the verification and recovery modules and differ only in identity and guardrails. A/B tests become module swaps instead of prompt rewrites. When a new model version arrives, you re-run the module tests instead of re-reading a wall of text and hoping.

The implementation does not need a framework. A registry and a build function are enough:

```python
from dataclasses import dataclass

@dataclass
class PromptModule:
    name: str
    version: str
    text: str
    owns: list[str]  # behaviors this module is responsible for

MODULES = {
    "identity": PromptModule("identity", "1.3", "...", ["role", "scope"]),
    "task_contract": PromptModule("task_contract", "2.0", "...", ["output format", "completion criteria"]),
    "tool_policy": PromptModule("tool_policy", "1.7", "...", ["tool selection", "tool scope"]),
    "verification": PromptModule("verification", "1.2", "...", ["pre-answer checks"]),
    "guardrails": PromptModule("guardrails", "1.5", "...", ["refusals", "escalation"]),
}

def build_prompt(enabled: list[str]) -> str:
    parts = [MODULES[name] for name in enabled]
    return "\n\n".join(
        f"<!-- module: {m.name} v{m.version} -->\n{m.text}" for m in parts
    )
```

The HTML comments look like decoration. They are not. When a trace shows the assembled prompt, the comments tell you exactly which module version produced each block, which turns "the prompt did something weird" into "module tool_policy v1.7 did something weird." That attribution is the whole game.

## Testing: the part that makes it real

Modules without tests are just a mega-prompt with headings. The test strategy has three layers, and each layer catches a different class of failure.

Layer one is module isolation tests. Run the module alone, with a probe designed to exercise exactly what it owns, and assert on the outcome. A tool policy module gets probes where two tools are near neighbors, and the test asserts the right one is chosen. A guardrails module gets probes that should escalate, and the test asserts the escalation happens and the forbidden action does not. A module that cannot pass a test in isolation is not a module, it is a wish.

```python
def test_module(module_name, probe, must_do, must_not_do):
    prompt = build_prompt([module_name])  # module in isolation
    out = run_agent(prompt, probe)
    assert must_do(out), f"{module_name} failed to do its job on: {probe}"
    assert not must_not_do(out), f"{module_name} violated its boundary on: {probe}"
```

Layer two is pair tests. Take two modules whose responsibilities touch, tool policy and verification, or guardrails and task contract, and run probes where both apply. This is where interaction bugs live, and pair tests are cheap enough to run on every change. You do not need to test every pair, just the ones that have bitten you before and the ones whose boundaries are adjacent.

Layer three is the regression suite against the full assembled prompt. This is your existing eval set, unchanged in purpose, but now useful in a new way: when a full-prompt regression appears, you bisect by module. Swap modules out one at a time until the regression disappears. The module that makes it disappear owns the bug. That bisection turns a day of prompt archaeology into an hour of targeted work, and it is the single biggest practical payoff of the whole approach.

One discipline makes all three layers work: every production incident gets a module test before it gets a module edit. The failing probe goes in first, the fix second, and the test stays. Over time this builds a suite that encodes what your agent has actually survived, which is a far more honest specification than the prompt text itself.

## Honest trade-offs

This is not free, and it is not always the right call.

It adds indirection. A new team member cannot just open one file and read the prompt; they read a registry, a build function, and a set of modules. For a prototype, a weekend project, or an agent with a short prompt and one owner, that indirection is pure overhead. Do not modularize a prompt that fits on one screen. The technique pays off when the prompt has outgrown one person's head, and not before.

Modules can still conflict. Composition does not resolve contradictions, it only makes them locatable. You still need someone to decide what wins, and pair tests only catch the conflicts you thought to probe. A team that modularizes and then stops testing has built a more organized version of the same problem.

Ordering is a real design burden. Get the precedence convention wrong and you get a new class of bug: behavior that changes when modules are reordered, which is exactly the kind of spooky interaction you were trying to escape. Write the convention down, test it, and resist reordering casually.

And none of this fixes bad instructions. A module that says "be helpful" is no better than a mega-prompt that says "be helpful." Modularity is a structure for good instructions, not a substitute for them. If your rules are vague, you will now have vague rules with version numbers.

## Migrating in a week

You do not need a rewrite. The migration I have seen work goes like this. Day one, audit: print the prompt, and delete every rule you cannot justify. This alone usually removes a surprising amount of dead text, and it is safe precisely because nobody can justify those lines. Day two, split what remains along the job boundaries above, and give each module a name and a version. Day three, write one isolation test per module, just one, for the behavior each module most needs to guarantee. Day four, wire up composition and the full-prompt regression suite with bisection. Day five, freeze the old prompt: all future changes go through modules, and every incident adds a test first.

The psychological shift matters as much as the technical one. Once a rule has a name, a version, an owner, and a test, deleting it stops feeling dangerous, because the test will tell you if it was load bearing. Teams that reach that point start pruning again, and the prompt gets shorter over time instead of longer. That reversal, from a document that only grows to a system that gets maintained, is the real outcome. The modules are just the mechanism that makes it safe.

So stop appending. The next time something breaks and your instinct is to add a paragraph, ask instead: which module owns this behavior, what test proves the fix, and what dead rule can this new understanding replace? A prompt you can test is a prompt you can trust. A prompt you can only append to is a liability with good formatting.

What is the oldest rule in your system prompt, and could you delete it today without anything breaking? If you are not sure, that uncertainty is the diagnosis.
