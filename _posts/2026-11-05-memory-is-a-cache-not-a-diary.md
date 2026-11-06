---
layout: post
title: "Memory Is a Cache, Not a Diary"
description: "Most teams treat agent memory as a transcript to preserve forever, and long context models made the habit worse. Memory is a cache: facts have TTLs, entries go stale, invalidation is the hard part, and a hit on a stale fact is worse than a miss. Design memory with expiry, supersede on write, and freshness checks on read, or your agent will confidently act on a past that no longer exists."
date: 2026-11-05
tags: [agents, memory, context, production, design]
---

Most practitioners get agent memory wrong in one specific way. They treat it as a diary. Every interaction gets recorded, every preference gets saved, every fact the agent ever learned gets appended to a growing transcript, and the whole pile gets stuffed into context on the next turn. The diary only grows. Nothing is ever removed, nothing is ever checked, and nothing is ever allowed to be wrong.

Long context models made this habit worse. When the window was 8k tokens, memory had to be selective, because there was no room for anything else. Now that vendors advertise million token windows, the temptation is to stop selecting at all. Just keep everything. The model will sort it out. That sentence is doing a lot of work, and almost none of it is true.

Here is the thesis: memory is a cache, not a diary. A cache exists to serve the next decision, fast, with a known freshness guarantee. A diary exists to preserve the past. Confuse the two and you get an agent that remembers everything and knows nothing, because it cannot tell which of its memories is still true.

## The diary fallacy

The diary model fails in a way that is easy to miss, because it fails quietly. An agent that stores facts forever does not visibly break. It keeps answering. It keeps acting. What changes is subtler: its answers slowly drift away from the user's current reality, and nobody notices until the drift causes a real mistake.

Consider a support agent that remembers a customer prefers refunds to store credit. That was true in March. In June the customer changed their mind, and told the agent so, in a conversation that was also recorded. The diary now contains two facts that contradict each other, and the agent has no rule for resolving the contradiction except recency, which is not a rule, it is a hope. If the newer fact happens to be retrieved, the agent is right. If the older one wins the retrieval ranking, the agent issues the wrong refund and sounds confident doing it.

That is the core failure mode of diary memory: it accumulates contradictions. Every preference change, every corrected fact, every superseded decision adds another entry that disagrees with an earlier one. The memory store gets richer and less reliable at the same time. Retrieval does not fix this, because retrieval ranks by similarity, not by truth.

## What a cache actually gives you

A hit means the fact was present and fresh. A miss means it was absent or expired, and the agent must fetch it from the source of truth. A TTL, time to live, is how long a fact is trusted without rechecking. Eviction is the policy for what leaves when the cache is full. Invalidation is marking an entry untrustworthy before its TTL runs out, because something changed the underlying truth. Each term names a decision teams usually skip.

Notice what is missing from that list: permanence. Nothing in a cache is stored forever. That is not a limitation. It is the feature that keeps the cache honest. A fact that cannot expire cannot be wrong in a detectable way, and a memory system that cannot be wrong in a detectable way will be wrong in an undetectable way, which is far worse.

The most important cache concept for agents is the stale hit. A miss is cheap and visible: the agent does not know, so it asks, or it looks it up. A stale hit is expensive and invisible: the agent knows, confidently, and what it knows is false. Every memory design decision should be judged by one question: does this make stale hits more or less likely?

## Not all facts expire at the same rate

The first design move is to stop treating memory as one bucket. Facts have wildly different shelf lives, and a single retention policy guarantees that some facts are kept too long and others are discarded too soon.

A user's name, language, and timezone are effectively permanent. Store them with a long TTL, and recheck them rarely. A stated preference, like a preferred refund method or a formatting style, lasts weeks to months, and changes without warning. Give it a medium TTL and a supersede rule, so a new statement about the same subject replaces the old one instead of joining it. A fact about the outside world, like a price, an inventory level, or a policy, is not memory at all. It is a snapshot of something that changes on its own schedule, and it should be verified on read, every time, or not stored at all.

This is where the diary model does its worst damage. It stores a price the way it stores a name, with the same permanence, and then the agent quotes last month's price as if it were today's. The fix is not better retrieval. The fix is refusing to cache things that should be looked up. Memory is for facts the agent cannot cheaply re-derive. If the source of truth is one tool call away, the cache adds a staleness risk for no benefit.

## Invalidation is the hard part

Every cache designer learns the same lesson: writing is easy, invalidation is the whole job. The same is true for agent memory, and it is the part most teams never build.

Invalidation has to happen on two triggers. The first is a contradiction: the user says something that conflicts with a stored fact. The write path must detect the conflict and supersede the old entry, not append a new one alongside it. Append is the diary behavior. Supersede is the cache behavior. If your memory store has no supersede operation, you do not have memory. You have a log.

The second trigger is an external event. The user updates their address in another channel. A policy changes. A subscription lapses. The agent was not present for any of these, so no contradiction ever arrives in conversation. The only defense is the TTL: the entry expires, the next read misses, and the agent fetches the current value. This is why TTLs matter even for facts that feel stable. The TTL is not there for the facts you expect to change. It is there for the changes you will never hear about.

## What long context claims get wrong

The standard pitch for long context as memory goes like this: the window is huge, so put the whole history in, and the model will find what it needs. There are three problems with that pitch, and all three are mechanical, not philosophical.

First, retrieval inside a long context is not free. The model attends over everything you put in, and attention is limited even when the window is large. A fact buried among ten thousand irrelevant tokens is not retrieved, it is diluted. The needle in a haystack benchmarks vendors love to cite measure whether a fact can be found. They do not measure whether the model can reason correctly when the context also contains five older, contradictory versions of the same fact. Finding is not the same as deciding.

Second, long context does not resolve contradictions. It preserves them, in full, and hands the resolution problem to the model at inference time, on every turn. A cache resolves the contradiction once, at write time, and every later read benefits.

Third, cost and latency scale with what you stuff in. Every token of history is a token you pay for on every turn. A diary that grows without bound is a cost curve that grows without bound, attached to a quality curve quietly declining as contradictions accumulate. Teams that adopt the stuff everything approach usually discover this in the bill before they discover it in the evals.

Long context is genuinely useful for reasoning over a large document in a single session. The mistake is treating a reasoning window as a storage system. A window is for thinking. A cache is for remembering. They are different tools, and using one as the other gives you the worst of both.

## A memory design that actually works

Here is a concrete shape that holds up in production. Every memory record carries the fact itself, where it came from, when it was written, how long it is trusted for, and when it was last verified. The source matters, because a fact the user stated is not the same as a fact the agent inferred, and an inferred fact should expire faster.

```python
@dataclass
class MemoryRecord:
    fact: str
    subject: str          # what the fact is about, for conflict detection
    source: str           # "user-stated", "inferred", "tool-result"
    written_at: datetime
    ttl_seconds: int      # trust window, set per fact type
    last_verified: datetime

    def is_fresh(self, now: datetime) -> bool:
        return (now - self.last_verified).total_seconds() < self.ttl_seconds

def write_memory(store, record: MemoryRecord):
    # Supersede, never append: same subject, new fact replaces old.
    store.supersede(subject=record.subject, new=record)

def read_memory(store, subject: str, now: datetime):
    record = store.get(subject)
    if record is None:
        return None  # a miss: go fetch from the source of truth
    if not record.is_fresh(now):
        store.invalidate(subject)
        return None  # a stale hit is worse than a miss
    return record
```

The read path has exactly one interesting decision: a stale entry is treated as absent. That converts silent corruption into a visible miss, and a miss is something the agent knows how to handle. It asks, or it looks it up. What it does not do is act on a fact it should have stopped trusting. The write path has one interesting decision too: supersede on subject. When the user states a new preference about a subject that already has a record, the old record is replaced, and the replacement is logged somewhere durable, because the history of what changed is still useful for auditing. But the audit trail is not the working memory. Keep the history in a log. Keep the cache clean. The diary belongs in the log, where it cannot poison a decision.

Compaction fits the same model. A periodic job that summarizes old conversation into memory is a cache refresh: re-derive the current facts, write them with fresh TTLs, and let the entries that no longer matter expire. If your compaction step only adds entries and never removes any, it is not compaction. It is hoarding with extra steps.

## The honest trade-offs

Caching memory has real costs, and they are worth naming, because they are the reason teams drift back to the diary.

Forgetting is the obvious one. A TTL that is too short means the agent asks the user for something they already told it, and nothing erodes trust faster than an agent that cannot remember what you said last week. The fix is TTLs that match the fact type, and a verification step that refreshes a record instead of expiring it when the fact is confirmed. A fact the user reaffirms is not a new fact. It is the same fact with a new timestamp.

Over-eviction is the subtler cousin. An aggressive cache that drops useful context forces the agent to re-derive things it should have kept, which costs tokens and latency and sometimes produces a worse answer than the cached one. The fix is measurement: track your hit rate, your stale hit rate, and your miss cost, and tune TTLs on evidence. A memory system without those three numbers is a preference, not a design.

## What to do on Monday

Do not start with a rewrite of your memory system. Start with an inventory. List every fact type your agent stores, and write down a TTL for each one. You will find facts with no expiry at all, which are the stale hits waiting to happen, and facts about the outside world that should not be cached in the first place.

Then find one contradiction in your stored memory. There will be one: a preference that changed, a fact that was corrected, a decision that was reversed. Check whether your system kept both versions. If it did, build the supersede operation before you build anything else. It is a small change, and it is the difference between a memory and a pile.

The deeper point is about what remembering is for. An agent does not remember so it can recite its past. It remembers so its next decision is better than its last one. A cache serves that purpose. A diary serves a different one, and it serves it at the cost of the decisions. Give your agent a memory with an expiry date, and it will forget some things it should have kept. Give it a memory without one, and it will act on things that stopped being true a long time ago. The first failure is visible and fixable. The second one is invisible until it is not.

Which fact in your agent's memory are you least sure is still true? That is the one to put a TTL on first.
