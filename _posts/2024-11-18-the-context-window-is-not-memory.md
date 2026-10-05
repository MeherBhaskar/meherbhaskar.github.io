---
layout: post
title: "The Context Window Is Not Memory"
description: "Stuffing more tokens into the window is not memory. Memory needs write, read, update, and forgetting."
date: 2024-11-18
tags: [craft, agents]
---

Every few months the context window gets bigger and someone declares that memory is solved. It is not. A bigger window is a bigger desk, not a filing system. You can pile more papers on it, but nothing is organized, nothing is updated, nothing is thrown away, and you still cannot find the one fact you need when you need it.

Long context and memory are different things that happen to share a medium. Confusing them produces systems that remember everything and recall nothing.

## What goes wrong with "just put it in context"

The failure modes are well documented by now, and they all rhyme.

**Lost in the middle.** Models attend best to the start and end of long contexts. Bury a crucial fact in the middle of 100k tokens and it might as well not be there. Position is not neutral, so stuffing the window is not the same as making information available.

**Stale facts never die.** Context is append-only amnesia. Once a fact enters the window, it stays, even after it is contradicted three pages later. The model now holds two conflicting facts and no principled way to choose. Real memory updates; context just accumulates.

**No provenance.** A fact in the window carries no record of where it came from, how confident the source was, or when it was learned. Was this a user statement, a tool output, an inference the model made itself three turns ago? Without provenance, the model cannot weigh evidence, and neither can you when debugging.

**Attention dilution.** Every token in the window competes for the model's attention. Ten thousand tokens of marginally relevant history actively degrade reasoning about the current task. More context is not free; it taxes everything else.

**No forgetting.** Human memory forgets, and that is a feature. Forgetting discards the irrelevant, the superseded, the wrong. A context window forgets only by truncation, which is the crudest possible policy: keep the most recent, drop the rest, regardless of value.

## What memory actually requires

A real memory system has verbs, not just capacity. Four of them, minimum:

**Write.** Deciding what to store, and in what form. Not everything deserves memory. The write path should extract durable facts from ephemeral conversation, normalize them into a consistent schema, and attach provenance: source, timestamp, confidence. Raw transcripts are not memory; they are the raw material memory is distilled from.

**Read.** Retrieval by relevance to the current need, not by recency. This is a retrieval problem wearing a memory costume, which means all the retrieval engineering applies: good indexing, ranking, and the discipline of fetching a little, well-chosen information instead of dumping the archive.

**Update.** Facts change. The user's preferences change, the world changes, earlier conclusions get corrected. A memory system needs conflict detection and resolution: when new information contradicts stored information, something has to decide what wins, and record why. Recency is not truth; sometimes the old fact was right and the new claim is the error.

**Forget.** Explicit policies for what expires and what gets corrected. Stale facts should decay. Wrong facts should be retracted, not just contradicted. A memory that only grows is a landfill.

And across all four: **provenance.** Every stored fact should know where it came from and how sure we are. Provenance is what lets the system resolve conflicts, what lets you debug bad behavior, and what lets the model express calibrated uncertainty instead of confident amnesia.

## A minimal architecture

You do not need a grand cognitive architecture. A workable minimal design has three stores:

**Working memory** is the current task state: what the user wants right now, what has been tried, what is pending. Small, structured, rewritten constantly. This is the only thing that belongs in the prompt by default.

**Episodic memory** is the compressed history: past interactions distilled into summaries, indexed for retrieval. Not transcripts, distillations. When the current task rhymes with a past one, the relevant episode gets pulled in.

**Semantic memory** is the durable fact store: user preferences, domain facts, learned corrections. Each entry has provenance, a timestamp, and a confidence. This is the store with real update and forget semantics.

A retrieval layer sits in front of all three, deciding what the current moment needs. The default should be restraint: fetch little, fetch well. The failure mode to avoid is the eager assistant that drags the entire past into every present.

```json
{
  "fact": "user prefers concise summaries over detailed reports",
  "source": "user correction in session 2024-11-02",
  "confidence": 0.8,
  "last_confirmed": "2024-11-18",
  "supersedes": null
}
```

That shape, a fact with provenance and lifecycle metadata, is worth more than a million tokens of undifferentiated context.

## When stateless is actually fine

Not everything needs memory, and building memory you do not need is its own failure mode. Stateless is correct when the task is self-contained: everything the model needs is in the current request, there is no cross-session personalization worth keeping, and past interactions do not improve future ones.

Plenty of production agents are like this. A classifier, a one-shot generator, a tool that answers from retrieved docs: these do not need to remember you. Adding memory adds failure modes, stale facts, privacy surface, and debugging complexity, for zero benefit.

The question is not "how do we give it memory" but "what would memory change about the outputs." If you cannot name the decision that past information would improve, you do not have a memory problem. You have a context assembly problem, or no problem at all.

## Memory is also a liability surface

Everything stored is a liability. A memory system persists user data, which means it inherits every hard problem of data retention: what is stored, for how long, who can see it, and how a user deletes it. "The agent remembered" is delightful until the remembered thing is sensitive, wrong, or both.

Wrong memories are the sharpest edge. A fact stored with high confidence that turns out to be false will poison every future decision that touches it, quietly, for as long as it lives. This is why the update and forget verbs matter more than write and read: a memory system is judged by how it handles being wrong, not by how much it accumulates.

Then there is poisoning, deliberate or accidental. If memory writes accept tool outputs or third-party content without scrutiny, an attacker (or just a confusing document) can plant facts that the system will later treat as its own knowledge. Every write path needs the same skepticism you would apply to user input, because that is what it is.

The practical stance: store the minimum that changes decisions, attach provenance to all of it, make deletion a first-class operation, and review what the system believes about your users the way you would review a database migration. Memory is powerful precisely because it persists. Persistence without governance is a time bomb.

## The reframe

Stop asking how big the window is. Start asking what the system remembers, how it updates what it remembers, what it forgets, and whether any of it can be inspected and debugged. Those are the questions that separate a system with memory from a system with a large desk.

The window is where thinking happens. Memory is what the thinking can draw on. Conflating them gives you the worst of both: all the cost of long context with none of the reliability of real recall.

What is the one fact your agent keeps forgetting that it should remember?
