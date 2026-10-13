---
layout: post
title: "Fine-Tune or Prompt? An Honest Decision Framework"
description: "Most teams fine-tune for the wrong reasons. A practitioner's framework for when fine-tuning actually beats prompting, when it is a distraction, and how to run the comparison honestly before you spend a dollar."
date: 2026-10-12
tags: [fine-tuning, prompting, llm, production]
---

Most fine-tuning projects I have seen are not engineering decisions. They are confessions.

A team has a prompt that sort of works, an agent that is inconsistent in a way nobody can quite pin down, and a deadline. Somebody says "we should fine-tune," and the room nods, because fine-tuning sounds like doing something serious. Three weeks later they have a model that is inconsistent in new and exciting ways, plus a training pipeline they now have to maintain forever.

I am not against fine-tuning. I have seen it work, in the specific cases where it is the right tool. But the industry conversation around it is badly broken, so here is the honest version: what fine-tuning can actually change about a model, what it cannot, and a decision framework you can run before you commit.

## The thing most practitioners get wrong

The common mental model is that fine-tuning teaches the model things, the way you would teach a junior engineer a new skill. Give it examples of good outputs, and it learns to do the task.

That model is wrong in a way that matters. Fine-tuning does not teach a model new facts. It adjusts the model's output distribution: it makes some completions more likely and others less likely, given similar prompts. It is preference-shaping, not knowledge installation.

This is why the canonical fine-tuning failure looks like this: a team fine-tunes on their domain data expecting the model to "learn" the domain, and the result is a model that sounds more like a domain expert while being wrong about the same things it was wrong about before, only now with more confident jargon. They taught it the accent, not the knowledge.

If your problem is that the model does not know your facts, your policies, or your data, that is a retrieval and context problem, not a weights problem. Put the knowledge in the context. Fine-tuning cannot make a model recall facts it never saw in training, and the attempts to do so reliably produce the worst of both worlds: hallucinations that sound on-brand.

So the first branch of the framework is a question: **is my problem knowledge, or behavior?**

Knowledge problems need data in context. Behavior problems, the shape of outputs, the reliability of formats, the consistency of style, are where fine-tuning can earn its keep.

## What fine-tuning is actually good at

Strip away the hype and fine-tuning does four things well:

**1. Format and style at scale.** If every output needs to follow a specific schema, tone, or structure, and your prompts are growing longer to enforce it, fine-tuning moves that cost from every inference to one training run. This is the clearest win. A support agent that must reply in a exact ticket format, a classifier that must emit exactly one label, a summarizer with a house style: these are distribution-shaping problems, and fine-tuning solves them.

**2. Compressing a long prompt into weights.** A 4,000-token system prompt is expensive at every call and fragile at every edit. If those instructions are stable, fine-tuning bakes them in. You trade prompt tokens for training effort. The math favors fine-tuning when the instruction set is fixed and the call volume is high.

**3. Teaching tool-use conventions.** Models are generalists at function calling. If your agent needs unusual conventions, calling tools in a specific order, emitting parameters in a specific dialect, knowing when not to call a tool, fine-tuning on good traces teaches the pattern more reliably than examples in context. This is the most underappreciated use case: fine-tuning as behavior programming for agentic systems.

**4. Distilling to a smaller, cheaper model.** Train a big model (or collect traces from one) to do the task well, then fine-tune a small model on those traces. You get most of the capability at a fraction of the latency and cost. This is the one case where fine-tuning pays for itself in the most literal sense: it shows up on the bill.

Notice what is not on the list: teaching facts, fixing reasoning, making the model smarter. Fine-tuning on reasoning traces can improve the style of reasoning outputs, and distillation from a stronger model can transfer capability, but you cannot fine-tune your way past what the base model can already do. A fine-tune is a sharpening of existing capability, not an upgrade to a new one.

## The decision framework

Here is the sequence I actually run through, in order:

**Step 1: Have you maxed out the prompt?** Before touching fine-tuning, check the basics. Is your best prompt actually good, or is it the first draft that happened to work? Have you tried the task with the strongest available base model? Have you tried breaking the task into smaller steps? Have you tried structured output with a schema? An embarrassing number of fine-tuning projects are really "our prompt was mediocre" projects. Be honest here. I have a rule: if you cannot describe exactly which failure mode the prompt cannot fix, you are not ready to fine-tune.

**Step 2: Knowledge or behavior?** As above. Knowledge gaps go to retrieval. Behavior gaps are fine-tuning candidates.

**Step 3: Is the behavior stable?** Fine-tuning bakes in what you train on. If your requirements change monthly, you are signing up to retrain monthly, and each retrain is a regression risk. Fine-tune only the parts of behavior that are genuinely stable: formats, conventions, style guides. Keep the volatile parts in prompts, where you can change them in minutes.

**Step 4: Do you have the eval to compare honestly?** This is the step everyone skips, and it is the most important one. You need a held-out eval set that measures what you actually care about, and you need to run the base model with your best prompt against the same set. Most fine-tuning claims I see compare a fine-tuned model against a weak baseline: an old prompt, a weaker model, vibes. Run the fair fight first. Sometimes the prompt wins, and you just saved three weeks.

**Step 5: Will the volume pay for it?** Fine-tuning has fixed costs (data curation, training, eval, pipeline maintenance) and per-call savings (shorter prompts, smaller models). If you make a hundred calls a day, the savings never amortize. If you make a million, they dominate. Do the arithmetic before you commit.

If you pass all five steps, fine-tune. If you fail any one, fix that one first.

## How to run the comparison honestly

The practical machinery is simple and most teams skip half of it:

```python
# The comparison that matters, run before any training
baseline = eval_model(base_model, best_prompt, held_out_set)
candidate = eval_model(fine_tuned_model, minimal_prompt, held_out_set)

# Measure on the SAME set, with the SAME rubric:
# - task success rate (your real metric, not a proxy)
# - format compliance rate
# - regression rate on OLD behaviors you care about
# - cost per 1k calls at your actual volume
```

Three things to note. First, the held-out set must be genuinely held out: no examples from it in training, no prompts tuned against it until you decide. Second, measure regressions, not just improvements. Fine-tuning shifts the whole output distribution, and the thing that got worse is usually something you did not think to check, like the model suddenly being terse in a context where it used to explain. Third, measure the minimal prompt against the fine-tuned model, because the point of fine-tuning is often that you no longer need the elaborate prompt. Comparing fine-tuned model with no prompt against base model with your best prompt is the real question.

One more practice that saves pain: keep a "prompt parity" artifact. When you fine-tune, write down the prompt you would have used, and keep it. When the base model updates (and it will, silently, underneath your API), re-run the comparison. Fine-tuned models drift against moving baselines, and the fine-tune that beat last quarter's base model may lose to this quarter's. This is the eval regression problem in miniature, and it is why step 4 is not a one-time activity.

## The contrarian take

Here is the stance I will defend: **the default should be prompting, and fine-tuning should have to earn its place.**

This is contrarian because the industry incentives run the other way. Fine-tuning sounds advanced. It looks like deep work on a resume. Vendors sell it. Conferences feature it. Prompting sounds like typing, so it gets undervalued even though, for most production tasks, a well-engineered prompt on a strong base model beats a mediocre fine-tune on a weaker one.

But there is a deeper reason for the default. Prompts are inspectable, versionable, and changeable in minutes. Fine-tuned weights are opaque artifacts with a maintenance tail: retraining cadence, eval pipelines, drift monitoring, and a team that has to understand both. That tail is worth it when the framework says so. It is not worth it as a reflex.

The teams I have seen get the most from fine-tuning share a pattern: they fine-tune late, not early. They ship with prompts, build the eval set from production traffic, find the specific behavior gap the prompt cannot close, and then fine-tune exactly that. Fine-tuning as the last optimization, not the first architecture decision.

## The thesis

Fine-tuning is not a way to make your model smarter. It is a way to make a specific behavior cheaper and more consistent. Every fine-tuning decision should survive this sentence: "The behavior is stable, the prompt cannot close the gap, the eval proves the win, and the volume pays for the pipeline." If you cannot say all four, you are not fine-tuning. You are hoping.

What is the fine-tuning project you almost started, and which of the four clauses stopped you? I am genuinely curious where the framework bites hardest in practice.
