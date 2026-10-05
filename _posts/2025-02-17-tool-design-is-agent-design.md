---
layout: post
title: "Tool Design Is Agent Design"
description: "An agent is only as good as its tools. Schema discipline, descriptions as UX, and errors the model can act on."
date: 2025-02-17
tags: [craft, agents, tools]
---

When an agent fails, the team blames the model. The model was confused, the model hallucinated, the model needs a better prompt. But trace the failure to its root and with remarkable frequency you find the same culprit: the tool. Vague description, sloppy schema, cryptic error, silent misbehavior. The model did its best with a bad instrument.

An agent is only as good as its tools. Tool design is agent design, and most teams design their tools like afterthoughts.

## Descriptions are UX, and the user is the model

The tool description is the most-read, least-crafted text in the entire system. The model reads it every time it considers the tool. And what does it usually say? Something like "Searches the database for records." That tells the model almost nothing it needs: which database, what counts as a record, what the parameters mean, when to use this tool versus the other three that sound similar, and critically, when not to use it.

Write descriptions for the actual reader. The reader is a language model deciding among tools under uncertainty. It needs: what the tool does in concrete terms, what each parameter means with examples, when this tool is the right choice, when it is the wrong choice, and what the output looks like.

```json
{
  "name": "search_orders",
  "description": "Search customer orders by status, date range, or order ID. Use this when the user asks about a specific order or wants to list orders matching criteria. Do NOT use this for product catalog questions; use search_products instead. Returns orders sorted by date, newest first, with line items included.",
  "parameters": {
    "status": {"type": "string", "enum": ["pending", "shipped", "delivered", "cancelled"], "description": "Filter by order status. Omit to include all statuses."},
    "since": {"type": "string", "description": "ISO date, e.g. 2025-01-01. Orders placed on or after this date."}
  }
}
```

Notice the negative instruction: when not to use it. Models choosing among similar tools need disambiguation more than they need encouragement. Every tool description should answer "why this tool and not the neighboring one."

## Schemas are contracts, so write them like contracts

Loose schemas produce loose behavior. A parameter typed as a bare string with no description invites the model to invent formats. An optional-everything schema invites the model to omit what matters. Ambiguous field names invite creative misinterpretation.

The discipline is the same as API design, because that is what this is:

**Tight types.** Enums over free strings wherever the values are known. Dates in ISO format, stated explicitly. Numbers with units named. Booleans that mean one thing.

**Required versus optional, deliberately.** Every optional parameter is a decision the model has to get right. Minimize them. If a parameter is almost always needed, make it required and let validation catch the omission loudly.

**No ambiguous names.** `query` could mean anything. `customer_email_substring` cannot be misunderstood. Verbose parameter names are free; misinterpretation is expensive.

**Examples in the schema.** A description with an example beats a paragraph of prose. Show the format, do not just describe it.

## Defaults carry weight

Every parameter with a sensible default is one fewer decision the model must make correctly. Pagination defaults, sort orders, result limits, timeout values: set them to what the common case needs.

But defaults must be visible. A default that silently narrows results, say returning only the first 10 of 10,000, will mislead the model into thinking 10 is all there is. Document defaults in the description, and when a default truncates, say so in the output: "showing 10 of 247 matching orders." The model cannot reason about what it does not know is hidden.

## Idempotency: retries will happen

Agents retry. They call the same tool twice because the first call timed out, because they are uncertain it went through, because the harness replays. If calling your tool twice creates two orders, charges twice, or corrupts state, that is a tool design failure, not an agent failure.

Design tools to tolerate repetition: natural idempotency where possible (reads, upserts keyed on stable IDs), explicit idempotency keys for writes, and clear semantics documented in the description. "Safe to retry" is a property worth stating outright. The model cannot be careful about what it does not know is dangerous.

## Errors the model can act on

The worst tool error is "Error 500" or, worse, silence. The model receives no information about what went wrong, so it does the only thing it can: try again, or guess. Both are bad.

Errors are a user interface too. A good tool error has three parts: what happened, in terms the model can understand; what the model can do about it; and the structured details needed to act.

```json
{
  "error": "invalid_date_range",
  "message": "The 'since' date 2025-02-30 is not a valid calendar date.",
  "recoverable": true,
  "suggestion": "Use a valid ISO date. Today is 2025-02-17."
}
```

Compare that to "Bad request." The first one lets the agent fix its own mistake and continue. The second one ends the task or starts a guessing spiral. Every error message should be written with the question: if the model reads this, does it know what to do next? If not, rewrite it.

Also: distinguish recoverable from fatal. A validation error is recoverable; an auth failure is not. The model should not burn five retries on something that will never succeed, and it cannot know the difference unless you tell it.

## Validate outputs before they poison the context

Tools lie, or rather, their outputs disappoint. A search returns an empty list, a parser returns malformed JSON, an API returns an HTML error page where JSON was promised. If that output flows straight into the model's context, the model will reason confidently from garbage.

Validate tool outputs against the expected schema before they reach the model. When validation fails, do not pass the raw garbage through; return a structured error describing what was expected and what arrived. This is the same contract discipline as inputs, applied in reverse. The boundary between tool and model should be the most validated boundary in your system, because everything downstream depends on it.

## Version your tools

Tools change: new parameters, changed behavior, deprecated endpoints. If the model was developed against version 1 and production silently runs version 2, you get the worst kind of bug: everything looks right and behaves subtly wrong.

Version tools explicitly. Pin the agent to known versions. When behavior changes, it should be a deliberate migration with evals run against the new version, not a silent drift discovered during an incident. Your tools are a dependency of your agent in the same way a library is a dependency of your code. Treat them with the same seriousness.

## The reframe

Stop asking whether the model is smart enough. Start asking whether the tools are well-designed enough. In my experience, the majority of agent failures I have traced had their root cause in tooling: a description that misled, a schema that permitted nonsense, an error that gave the model nothing to work with, an output that poisoned the context.

Every hour spent on tool design pays back many times over in reliability, because tools are leverage: one well-designed tool improves every task that uses it, while prompt tuning improves one task at a time.

Go read your tool descriptions as if you were the model, choosing among them under uncertainty, with no other context. Would you choose correctly? If not, you have found your next highest-leverage work.

Which of your tools would you least want to debug at 2am, and what does that tell you?
