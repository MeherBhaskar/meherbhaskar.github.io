---
layout: post
title: "Your System Prompt Has a Token Budget: Spend It Like One"
description: "Every token in your system prompt is a recurring cost paid on every call, and it competes for the model's attention. Most teams budget their context window never. Here is how to allocate tokens across instructions, examples, tools, and retrieved context by marginal value, and how to measure what each section actually earns."
date: 2026-10-24
tags: [agents, prompts, tokens, cost, production]
---

Most practitioners get system prompts wrong in a specific way. They treat the context window as free space. The model supports a large window, so they fill it. A paragraph for tone, a page of edge cases, twelve few-shot examples, every tool schema in full, plus whatever retrieval dumped in this turn. Nothing about that feels like a decision, because no line item ever shows up on an invoice labeled "the paragraph you added in March." But it is a decision, and you pay for it on every single call.

Here is the thesis: your system prompt has a token budget, whether you set one or not. Every token in it is a recurring cost, paid in money, latency, and attention, on every request. The teams that ship reliable agents treat that budget like a real budget: they allocate it across competing uses, they price every addition, and they cut things that do not earn their keep. The teams that do not end up with prompts that are simultaneously expensive, slow, and worse at following instructions than a shorter version would be.

## Four buckets competing for the same budget

It helps to stop thinking of the prompt as one blob and start thinking of it as four buckets that compete for the same tokens.

First, instructions: the rules, the role, the output contract, the safety boundaries. Second, examples: few-shot demonstrations of good behavior, good tool calls, good refusals. Third, tools: the schemas, the parameter descriptions, the usage notes. Fourth, retrieved context: the documents, the state, the conversation history, the tool results that arrive per turn.

Every token you give to one bucket is a token you cannot give to another, and a token that dilutes the rest. This is the part most teams miss. The budget is not only about the bill. A 6,000 token prompt does not just cost more than a 2,000 token prompt. It also asks the model to hold more in mind while it decides what to do next. Instructions compete with each other, examples compete with instructions, and a wall of tool schemas competes with the actual user request. Adding a rule can make an existing rule less likely to be followed, because following instructions is not a lookup. It is a competition for attention, and attention is the scarcest resource in the whole system.

The arithmetic on cost is simple enough to do on a napkin. Prompt tokens are paid on every call, not once. A prompt of P tokens sent on N calls costs P times N prompt tokens, before a single token of output. Double the prompt and you double that line, on every call, forever, including the calls where the extra paragraphs were irrelevant. The question is never "is this paragraph useful in some case." The question is "is this paragraph worth its price on every case, including the ones where it does nothing." Most paragraphs fail that test, and nobody notices, because the cost is spread thin across thousands of calls instead of arriving as one visible bill.

## Marginal value per token, not total value

The right mental model is marginal value. The first instruction that defines the output contract is worth a fortune. It turns an unusable ramble into a parseable result. The second instruction that clarifies an edge case in that contract is worth something. The fifteenth instruction about formatting, written after an incident nobody remembers, is worth almost nothing, and it still costs the same per call as the first one. Value per token falls off a cliff. Cost per token does not.

Examples follow the same curve, and this is where teams waste the most. The first few-shot example teaches the format. The second teaches a variation. By the sixth example of the same pattern, you are no longer teaching. You are repeating yourself to a model that already got it, at full price, on every call. Worse, each additional example narrows the model's idea of what a correct answer looks like. A set of examples that all look alike does not make behavior more robust. It makes behavior more rigid, and then the first genuinely novel input breaks in a way none of your examples covered.

Tool schemas are the quietest leak. A schema with ten parameters, each described in two sentences, plus a usage note, plus an example payload, can easily run to hundreds of tokens per tool. Multiply by fifteen tools and the tool bucket alone can exceed the instruction bucket several times over, before the user has said a word. Most of those tokens are never load bearing. Parameter descriptions that restate the parameter name, enums spelled out in prose and in the schema, and tools that are available on every call but needed on one call in twenty, all sit in the budget like subscriptions nobody uses.

Retrieved context is the bucket teams budget least and regret most. Retrieval that returns the top ten chunks "to be safe" is not being safe. It is spending the budget on the least curated content in the prompt, the content most likely to contain contradictions, stale facts, and instructions from untrusted sources. Every retrieved chunk should have to justify itself the same way an instruction does: does this specific chunk change the decision on this specific turn. If you cannot say how, it is filler, and filler in the retrieval bucket is worse than filler elsewhere, because it looks like evidence.

## Measure it: ablation is the budget review

You cannot allocate a budget by taste. You allocate it by ablation, which is just the budget review applied to prompts. Take a section out, run your evals, and see what moves. If removing a section changes nothing on your eval suite, that section is not earning its tokens. Either your evals do not cover what it does, in which case you need a test for that case before you defend the section, or the section is dead weight and you cut it.

Run this the other way too. Add a candidate section and require it to prove itself: a measurable improvement on a named eval, not a feeling that the prompt "reads better." Reading better is not a metric. A section that improves one eval and degrades another is not a win. It is a trade, and you should name the trade before you ship it.

This discipline does something else useful. It forces you to notice interactions. Remove the persona paragraph and watch tool-call accuracy move. Remove two examples and watch refusal quality move. Those movements are information. They tell you that sections are not independent, that the model was balancing them against each other, and that your prompt is a system with couplings, not a list. A prompt whose sections interact invisibly is a prompt you cannot reason about, and ablation is the cheapest way to make the interactions visible.

A practical shape for this is a budget check in CI, not a document nobody reads. Count tokens per section, fail the build when the total exceeds the budget, and require an explicit decision to raise the budget. The point is not the exact number. The point is that exceeding the budget becomes a visible, reviewable event instead of a silent append.

```python
# Fail CI when the prompt budget is exceeded.
# Each module is counted separately so the review
# shows which section grew, not just that the total did.
BUDGET_TOKENS = 2500

def check_budget(modules):
    counts = {name: count_tokens(text) for name, text in modules.items()}
    total = sum(counts.values())
    for name, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"{name}: {n} tokens")
    print(f"total: {total} / {BUDGET_TOKENS}")
    if total > BUDGET_TOKENS:
        raise SystemExit(
            "Prompt budget exceeded. Cut a section or "
            "raise the budget in review, with a reason."
        )
```

The number 2500 there is a starting point, not a law. Your budget depends on your latency target, your cost target, and how much retrieved context a turn needs. What matters is that the number exists, that it is enforced, and that raising it requires a human to say why the extra tokens are worth paying for on every call from now on.

## What is worth paying for

Not everything should be cut. Some tokens are cheap at any price, and knowing which ones is the actual skill.

Pay for the output contract. The format, the fields, the failure shape. If the downstream system cannot parse the result, nothing else matters, and a precise contract is the highest value text in the prompt.

Pay for the decision boundaries. When to act, when to ask, when to refuse, when to stop. These are the rules that prevent the expensive failures: an action taken that should not have been, a question asked that should not have been, a task declared done that was not. A boundary rule that prevents one bad action is worth more than ten paragraphs of tone guidance.

Pay for the one example that disambiguates. Not twelve examples of the common case. One example of the case people get wrong: the ambiguous tool call, the partial result, the refusal that still helps. Examples earn their tokens by covering the decision boundary, not by repeating the center.

Cut the rest first. Cut persona prose that restates the role in five ways. Cut examples that duplicate each other. Cut tool descriptions that restate the schema. Cut retrieval that you fetched "just in case." Cut rules for tools that no longer exist and edge cases for incidents that were fixed elsewhere. Every cut is a small latency win, a small cost win, and a small attention win, and those wins compound across every call you will ever serve.

There is an honest trade here, and it cuts both ways. A prompt that is too short fails differently: it under-specifies the contract, it leaves boundaries to chance, and it leans on the model to guess what you meant. The goal is not the shortest prompt. The goal is the prompt where every section can point to the eval it passes or the failure it prevents. Short is a side effect of that discipline, not the target. If a safety boundary needs two hundred tokens to state precisely, spend them, and say so in review. A budget is not an excuse to under-specify the things that matter. It is a reason to stop spending on the things that do not.

## Do this on your next prompt review

Open your system prompt and count it by section: instructions, examples, tools, retrieved context. Most teams have never seen those four numbers side by side, and the surprise is usually in the tool bucket or the examples bucket, not where they expected it. Then ablate one section at a time and watch your evals. Cut what does not move anything. For what remains, write one line next to each section: what it earns, and what test proves it. If you cannot write that line, the section is on probation, and probation should have a deadline.

That is the whole method. Set a budget, allocate it by marginal value, enforce it in CI, and make every addition defend itself. The context window will keep getting bigger, and that is exactly why this matters more, not less. A bigger window does not remove the budget. It just raises the price of never setting one.

What is the largest section in your system prompt right now, and could you name the eval it passes? If the answer is no, you already know where your next cut lives.
