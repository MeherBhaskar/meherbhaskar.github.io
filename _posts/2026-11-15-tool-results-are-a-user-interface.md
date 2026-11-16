---
layout: post
title: "Tool Results Are a User Interface: Design Them for the Model, Not the Program"
description: "Most teams design the tool call and ignore the tool result. But the model never sees your clean API. It sees the blob you return, and that blob is its entire interface to the world. Why raw API responses sabotage reasoning, how result shape changes what the model does next, and the design rules that turn tool outputs into something a model can actually use."
date: 2026-11-15
tags: [tool-design, agents, production-ai, ai-engineering, llm, context]
---

Most teams design the tool call and ignore the tool result. They agonize over the schema, the parameter names, the description string, and then they return whatever the underlying API happens to give back: a raw JSON blob, a 400 error code, a paginated dump of fifty records, and they call the integration done. That is backwards. The model never sees your clean API. It sees the blob you return, and that blob is its entire interface to the world.

Here is the thesis: a tool result is a user interface, and the model is the user. Every rule you know about good UI design applies, with the stakes raised, because this user reads everything you show it, gets confused by clutter it cannot filter, and makes decisions based on the first thing that looks like an answer. If you would not ship a UI that dumps a raw database row on a human and says "figure it out," do not ship a tool that does the same thing to a model.

## What the model actually sees

It helps to be concrete about what happens after a tool call returns. The result goes into the context window as text, usually wrapped in some framing the framework adds. The model reads it in order, top to bottom, and the next thing it does, another call, a clarification question, a final answer, is conditioned on what it just read. That means the result is not data passing through a pipe. It is the next prompt. Every field you include is a sentence in that prompt. Every field you omit is a fact the model cannot use.

This is where the standard approach quietly fails. A search tool that returns fifty results is not giving the model more to work with. It is giving the model fifty chances to pick the wrong one, plus several thousand tokens of noise that push the actual task further back in the context. An error response that says "400 Bad Request" is not an error message. It is a dead end with no next step, and the model will do what any user does at a dead end: guess. A record that returns every column of a database row is not thorough. It is a wall of fields where the three that matter are buried between internal IDs, timestamps in epoch format, and flags whose names mean something only to the engineer who wrote the schema.

The failure mode is easy to miss because it does not look like a failure. The tool works. The call succeeds. The result is technically correct. And the agent's behavior gets slightly worse in a way nobody traces back to the result shape, because the result shape is not instrumented, not reviewed, and not owned by anyone. The team debugs the prompt, swaps the model, adds a retry, and the real problem sits there in plain text: the model was shown a bad interface and did the best it could with it.

## The four design failures

Bad tool results fail in four recurring ways, and each one maps to a UI mistake you already know how to spot in human-facing design.

First, too much. The raw API response, unfiltered, is the equivalent of a settings page that shows every configuration option at once. A product lookup that returns the full record, descriptions, variants, inventory per warehouse, supplier codes, internal notes, is several hundred tokens of which the model needs maybe forty. The rest is not neutral. It competes for attention. Models are sensitive to what appears in context, and a long result does two kinds of damage at once: it costs tokens on every turn it stays in the window, and it dilutes the signal the model needs for its next decision. I have seen agents pick the wrong item from a search because the result list included a near-match with a more prominent description, and the right item was three entries down. The model did not fail at reasoning. It failed at reading a badly designed list.

Second, too little, or the wrong little. The opposite failure is the terse result that strips out exactly the context the model needs to act. A tool that returns `{"status": "ok", "id": 4821}` after creating a record tells the model nothing about what was created, whether the values it sent were accepted as given, or what the record now contains. The model has to either trust blindly or make a second call to read back what it just wrote, which is a wasted round trip that also doubles the chance of a stale read. The design question is not "what is the minimum we can return." It is "what does the model need to decide its next step without another call." The answer is usually a short summary of the effect: what changed, what the resulting state is, and what is now possible.

Third, errors that say nothing. This is the most expensive failure, because errors are where agents lose the most time. An API that returns a bare status code and a generic message hands the model a puzzle with no pieces. Compare the two responses below, both for the same failed call:

```json
{"error": "invalid_request", "code": 400}
```

```json
{
  "error": "invalid_request",
  "message": "The start date (2026-11-20) is after the end date (2026-11-15). Swap them and retry.",
  "fixable_by_model": true,
  "retry_with": {"start_date": "2026-11-15", "end_date": "2026-11-20"}
}
```

The first response leaves the model to guess what went wrong, and the guess is often wrong, which produces a second failed call, and then a third, and then a confident hallucination about what the user wanted. The second response is a UI that respects its user: it names the problem, it says whether the model can fix it, and it hands over the corrected values. The difference between these two is not polish. It is the difference between an agent that recovers in one step and an agent that burns three turns and still fails.

Fourth, structure that fights the model. Models read structured text well, but they read some structures much better than others. A deeply nested object with five levels of indentation forces the model to track hierarchy while also reasoning about content. A list of objects where the important field is the fourth key in each object makes comparison work harder than it needs to be. Dates as epoch integers, money as integer cents with no currency label, booleans named `flag_x` with no explanation, all of these are the equivalent of a form with unlabeled fields. The model will usually figure it out, and "usually" is doing a lot of work in that sentence. The cases where it does not figure it out are the cases that show up in production traces as inexplicable mistakes.

## The design rules

So what does a well-designed tool result look like? Five rules cover most of it.

Rule one: return the answer, not the data. The result should be shaped around the question the model asked, not the shape of the underlying store. If the tool is "find the cheapest available option," the result should lead with the cheapest available option, then list the next two, then stop. If the tool is "get the order status," the result should lead with the status in plain words, then the facts that support it. Put the most decision-relevant information first, because models, like people, overweight what they read first, and a result that buries the answer under metadata is a result that will be misread.

Rule two: pre-compute what the model would compute badly. If the raw data needs a comparison, a sort, a filter, a sum, or a date conversion, do it in code and return the result. Do not hand the model a list of timestamps and expect it to pick the latest one reliably. Do not hand it a list of prices in different currencies and expect correct conversion. Every computation you push into the model's head is a computation that can go wrong silently, and the model will not flag its own arithmetic as uncertain. It will just proceed. Code is deterministic. Use it.

Rule three: make errors actionable, and say when they are not. Every error result should answer three questions: what went wrong, in words the model can act on; whether the model can fix it by changing its call; and what to do instead if it cannot. If the error is not fixable, say so plainly and suggest the fallback, whether that is asking the user, using a different tool, or stopping. An error that says "not fixable, ask the user for X" is a good result. An error that says "400" and leaves the model to invent a recovery is a trap. One more point on errors: never return a success-shaped result for a failure. A tool that returns an empty list when the query failed is lying to the model, and the model will build a confident answer on that lie.

Rule four: bound the size, and say when you truncated. Decide a maximum result size, in tokens or records, and enforce it in code, not in hope. When you truncate, say so in the result itself: "showing the top 5 of 43 matches, refine the query to see more." That sentence does two things. It tells the model the list is incomplete, so it does not treat absence as evidence, and it tells the model how to get more, which is the correct next step. Silent truncation is one of the quietest ways agents go wrong, because the model has no way to know that the thing it is looking for was result number six.

Rule five: keep the shape stable, and version it like a contract. The model builds expectations about what a tool returns, and those expectations live in the prompt, in examples, in the model's own memory of previous turns. If the result shape changes, if a field disappears, if a list becomes a dict, the model does not get a migration guide. It gets a surprise, mid-conversation, and it will improvise. Treat the result schema the way you would treat a public API response: version it, document it, and never change it silently. This is the same argument I made about tool schemas and about prompts, and it applies here with the same force. The result is part of the contract.

## A before and after

Here is a concrete example, the kind of search tool most agent systems have. The before version returns what the search service returns:

```python
def search_products(query):
    raw = catalog.search(query, limit=20)
    return json.dumps(raw)  # full records, all fields
```

The model gets twenty full records, each with dozens of fields, most of them irrelevant, and has to pick the right product, compare prices, and notice that two of the results are out of stock. The after version does the work in code:

```python
def search_products(query):
    raw = catalog.search(query, limit=20)
    in_stock = [p for p in raw if p["stock"] > 0]
    in_stock.sort(key=lambda p: p["price_cents"])
    top = in_stock[:5]
    return json.dumps({
        "query": query,
        "shown": len(top),
        "total_matches": len(raw),
        "in_stock": len(in_stock),
        "results": [
            {
                "name": p["name"],
                "price": f"${p['price_cents'] / 100:.2f}",
                "stock": p["stock"],
                "id": p["id"],
            }
            for p in top
        ],
        "note": "Sorted by price, lowest first. Out-of-stock items excluded."
    })
```

The difference is not the amount of code. It is about twenty lines. The difference is what the model has to do with the result: in the first version, it has to filter, sort, convert, and compare, all in its head, from a wall of text. In the second version, it has to read a short list that is already sorted and already filtered, and pick. The first version is a data dump. The second is an interface. The second version also costs fewer tokens on every single turn, which matters more than most teams think, because tool results are the largest single consumer of context in a long agent session, and context is the budget everything else draws from.

## The trade-off, honestly

There is a real cost to this, and it is worth naming. Shaping results means writing code per tool, maintaining that code, and making judgment calls about what the model needs. That is work, and it is work that looks optional right up until the moment it is not. The tempting alternative is to pass everything through and let the model sort it out, and for a prototype that is the right call. For a system that runs in production, it is a tax you pay on every turn, in tokens, in latency, in reasoning errors, and in the debugging time you spend chasing failures that turn out to be a model misreading a result you could have shaped.

There is also a genuine tension between generality and specificity. A result shaped for one use case can be wrong for another. The same search tool might serve a comparison task and a lookup task, and the ideal result shape differs between them. The honest answer is to shape for the common case and include an escape hatch: a parameter that asks for more detail, or a follow-up tool that fetches the full record when the model actually needs it. Lazy detail beats eager detail. Give the model the summary by default and the full record on request, not the other way around.

And there is a limit to how far shaping goes. A perfectly shaped result cannot save a bad tool, a bad prompt, or a model that is not up to the task. Result design is not a substitute for any of those. It is a multiplier on them. A good result makes a good agent better and a bad agent slightly less bad. That is still worth doing, because in a production system the difference between "slightly less bad" and "bad" is often the difference between a user who trusts the system and a user who stops using it.

## The contrarian part

Here is the stance I will defend. The tool result is the most under-designed surface in agent engineering, and the teams that get it right will beat the teams with better models. That sounds backwards, and I mean it literally. Model capability is converging. The frontier models are close enough to each other on most agent tasks that the differentiator is no longer which model you call. It is what you show it. The team that returns a clean, ordered, bounded, actionable result gets better behavior out of a mid-tier model than the team that dumps raw API responses into a frontier model. I have watched this play out in practice: the same model, the same prompt, the same task, and the difference between a sloppy result and a shaped one is the difference between an agent that recovers from errors and one that spirals.

The reason teams miss this is that tool results are invisible work. Nobody demos a well-shaped error message. Nobody writes a launch post about truncating a search result to five items. The work that gets attention is the new model, the new framework, the new agent architecture. Result design is plumbing, and plumbing does not get applause. But plumbing is what decides whether the house floods. If your agent is behaving strangely and you have already tuned the prompt and swapped the model, look at what you are showing it. The answer is usually sitting in the result, in plain text, waiting for someone to read it the way the model does.

## What to do on Monday

Pick your most-called tool. Read ten of its recent results from production traces, the actual text the model saw. For each one, ask four questions. Did the model need everything in it? Was the decision-relevant information first? If the call failed, did the error say what to do next? Was anything truncated without saying so? The answers will tell you where to start, and the first fix is usually small: filter a field, sort a list, rewrite an error message, add a truncation note. That is an afternoon of work, and it will show up in your traces within a week, in fewer wasted turns and fewer inexplicable mistakes.

Then make result shape a review item. When a new tool is proposed, the review should cover the result as carefully as the schema: what does the model see, in what order, how big is it, what happens when it fails. Put it in the same checklist as the tool description and the parameter names. The teams that do this stop treating tool results as an afterthought, and their agents stop behaving like they are reading a database dump, because they are not anymore.

The sharp version: you are not building a tool. You are building the only window the model has into the world. Design the window.

What does your most-called tool actually return, and when did you last read it the way the model reads it?
