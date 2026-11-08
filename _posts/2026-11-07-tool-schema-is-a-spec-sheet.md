---
layout: post
title: "Your Tool Schema Is a Spec Sheet, Not a Label"
description: "Most teams write tool definitions as if they were labels on a jar, a name and a vague description, and then wonder why the model picks the wrong tool or fills the wrong argument. A tool schema is a spec sheet: the model is a client reading API docs under pressure. Three conventions most teams get wrong, and what borrowing from real API documentation actually looks like."
date: 2026-11-07
tags: [agents, tools, tool-design, production, api-design]
---

Most practitioners get tool design wrong in one specific way. They write the tool definition as if it were a label on a jar: a name, a one line description, a few parameters, done. Then they watch the agent call the wrong tool, pass a date where an ID was expected, or invent an argument that does not exist, and they blame the model. The model was not being careless. It was reading the only documentation it had, and the documentation was bad.

Here is the thesis: your tool schema is a spec sheet, not a label. The model is a client consuming an API it has never seen before, under time pressure, with no Stack Overflow to fall back on. Everything good API documentation does, precise types, examples, error contracts, guidance on when not to call, your tool definitions need to do too. Teams that treat the schema as an afterthought are debugging model behavior that is really documentation behavior.

## The label mindset

Look at a typical tool definition from a real production agent:

```json
{
  "name": "search_orders",
  "description": "Search for orders.",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {"type": "string"},
      "limit": {"type": "integer"}
    }
  }
}
```

This tells the model almost nothing. Search by what? Order ID, customer name, product, date range? Is `query` free text or a structured identifier? What does `limit` default to, and what is the maximum? What does a result look like, and what does it mean when the result is empty? Every one of those questions is a decision the model now has to make on its own, in the middle of a task, with no signal to guide it. Some of those guesses will be wrong, and the failures will look random, because they are: they depend on whichever phrasing happened to be salient in the conversation.

The label mindset survives because it works in demos. In a demo, the model gets one tool, one happy path, and a cooperative user. The schema never gets stressed. Production is where the schema gets stressed, because production is where the same tool is called from ten different intents, with ambiguous user input, under a token budget, and the only thing separating a correct call from a wrong one is what the definition actually says.

## Convention one: descriptions describe the happy path only

The first convention teams get wrong is writing the description for the case where the tool should be called, and never for the cases where it should not.

Good API docs have a "when to use this" section and, just as importantly, an implied "when not to." Stripe's docs do not just say what an endpoint does. They say what it is for, what it replaces, and what happens if you use it for the wrong thing. Tool definitions need the same treatment, because the model is constantly choosing between tools, and the choice is made on the description alone.

Consider two tools that overlap: `search_orders` and `get_order_details`. If both descriptions say "retrieve order information," the model has no basis to choose. The fix is to write the boundary into the schema:

```json
{
  "name": "search_orders",
  "description": "Find orders matching a filter when you do not yet know the order ID. Use this first to locate an order. Do NOT use this to fetch full details of an order you already identified; use get_order_details instead. Returns a summary list only: ID, customer, total, status. No line items.",
  "parameters": {
    "type": "object",
    "properties": {
      "customer_email": {"type": "string", "description": "Exact customer email. Partial matches are not supported."},
      "status": {"type": "string", "enum": ["pending", "shipped", "delivered", "cancelled"], "description": "Filter by order status. Omit to include all statuses."},
      "limit": {"type": "integer", "description": "Max results, 1 to 50. Default 10."}
    },
    "required": ["customer_email"]
  }
}
```

Notice what changed. The description now states the precondition (you do not know the order ID), the anti-pattern (do not use it for details), and the shape of the output (summary only, no line items). The parameters now carry enums, ranges, defaults, and a note about partial matching. None of this is clever. It is what any competent API reference does. The difference is that an API reference is read by a human who can guess and retry, while a tool schema is read by a model that guesses once and acts.

The contrarian point here is that many teams resist this because they think long descriptions waste tokens. They are right about the cost and wrong about the trade. A vague description costs far more in failed calls, retries, and wrong-tool invocations than a precise one costs in tokens. A tool call that goes to the wrong endpoint is not just one wasted call. It is a wasted call, plus the model's recovery attempt, plus the context consumed by the error, plus the user's patience. Precision in the schema is the cheapest reliability you can buy.

## Convention two: parameter types that say nothing

The second convention teams get wrong is treating JSON Schema types as documentation. `"type": "string"` is not a specification. It is a shrug. A string can be an email, a date, an ID, a SKU, a free text query, or a country code, and the model cannot tell which one you meant unless you say so.

Real API documentation never stops at the type. It gives the format, the constraints, and an example. OpenAPI has `format: date-time`, `pattern`, `minimum`, `maximum`, and `example` for exactly this reason. Tool schemas support the same fields, and most teams leave them blank.

Take a date parameter. `"start_date": {"type": "string"}` invites the model to send "last Tuesday," "Nov 7," "2026-11-07," or "yesterday," and three of those will fail or, worse, be silently misparsed. The fix:

```json
"start_date": {
  "type": "string",
  "format": "date",
  "description": "Start of the range, ISO 8601 date only, YYYY-MM-DD. Example: 2026-11-01. Never send relative dates like 'last week' or 'yesterday'; compute the date from the conversation first."
}
```

That last sentence matters more than the format field. It tells the model to do the computation before the call, because the tool cannot. Every parameter that requires the model to transform something, a relative date into an absolute one, a name into an ID, a phrase into an enum value, is a place where the transformation rule belongs in the schema, not in a system prompt the model may or may not consult at the right moment.

The same applies to enums. An enum without a description of each value is a multiple choice test with no question. If your status enum is `["open", "pending", "closed"]`, say what each one means in your system, because the model will map them to its own prior about what those words mean, and your system's meanings are almost certainly different. "Pending" in your order system might mean "awaiting payment," while the model's default guess is "awaiting processing." That mismatch is a silent bug, and it lives in the schema, not in the model.

## Convention three: no error contract

The third convention teams get wrong is the most damaging, and the easiest to miss: the schema says nothing about what happens when the call fails, or what the result looks like.

API documentation always specifies the error cases. A 404 means the resource does not exist. A 422 means your input was invalid, and here are the fields that can be wrong. A 429 means slow down. Tool definitions almost never do this, so when a call fails, the model has to infer the cause from an error string it may never have seen, and then decide whether to retry, rephrase, try another tool, or give up. That inference is where agents loop: retrying the same failing call three times, each time with slightly different phrasing, burning context and latency on a problem the schema could have prevented.

Write the error contract into the description. It does not need to be long:

```json
"description": "Cancel an order by ID. Fails with ORDER_SHIPPED if the order has already shipped; in that case, offer the returns flow instead of retrying. Fails with ORDER_NOT_FOUND if the ID does not exist; in that case, re-run search_orders to confirm the ID before telling the user the order is missing. This action is irreversible and triggers a refund to the original payment method."
```

Three sentences, and the agent now knows the two failure modes, the recovery for each, and the side effect it is committing to. That last part, the side effect, is the piece most teams omit entirely. A tool that charges a card, cancels an order, or sends a message should say so in its description, in plain language, because the model weighs the risk of a call partly on what the description says it does. A description that hides the side effect is not concise. It is deceptive, and it will produce confident, irreversible mistakes.

The same logic applies to the return shape. If the tool returns a paginated list, say so, and say how to get the next page. If it returns an empty list when nothing matches, as opposed to an error, say that, because the model needs to know that empty means "no matches," not "the tool broke." If the result is truncated, say what was cut. Every ambiguity in the return shape is a place where the model will hallucinate a confident interpretation.

## The trade-off nobody wants to admit

There is a real trade-off here, and honest writing means stating it. Verbose schemas cost tokens on every single call, because the definitions ride along in context. A team with forty tools and two hundred word descriptions is paying a meaningful tax, and at some point the tax exceeds the benefit. That is a real constraint, and it is why the answer is not "write a novel for every tool."

The answer is to spend the words where ambiguity is expensive. A read-only lookup with one unambiguous parameter needs three lines. A mutating tool with overlapping siblings, fuzzy inputs, and irreversible side effects needs a paragraph. The budgeting rule is simple: the more a wrong call costs, the more the schema should say. Teams that apply the same one line description to every tool are not being efficient. They are underwriting the dangerous tools with the same documentation budget as the harmless ones.

There is also a second-order effect worth naming. When you force yourself to write the error contract and the when-not-to-use section, you discover tools that should not exist. A tool whose description needs three paragraphs to distinguish it from its sibling is usually two tools that should be one, or one tool with a parameter that should be two tools. The schema is a design review disguised as documentation. If you cannot write a clear spec sheet for a tool, the tool is not ready, and no amount of prompt engineering will save it.

## How to know your schemas are good enough

You cannot evaluate a schema by reading it. You evaluate it the way you evaluate an API: by watching a client use it. Build a small golden set of tool call traces, not full conversations, just the decision points. For each trace, record the user intent, the tool the agent chose, and the arguments it passed. Then run the same traces after every schema change and watch for regressions. A schema edit that fixes one call and breaks two others is a net loss, and you will only catch it if you test the schema like a contract.

Two cheap checks catch most problems before the golden set does. First, the cold reader test: hand the schema to someone who has never seen the tool and ask them to predict what it returns for three inputs, including one invalid input. If they cannot, the model cannot either. Second, the overlap test: for every pair of tools, ask whether their descriptions could both plausibly match the same user request. If they can, the boundary is not written down, and the model will pick wrong roughly half the time, which is exactly the failure rate that looks like flakiness instead of a bug.

## The thesis, restated

Tools are the agent's hands, and the schema is the only instruction manual those hands ever get. Teams spend weeks on model selection, prompt tuning, and orchestration, and then hand the model a set of tool definitions that would embarrass a first draft API reference. That ordering is backwards. The model is replaceable. The schema is the interface, and the interface is the product.

Write your tool definitions like the API docs you wish you had: precise types with formats and examples, boundaries that say when not to call, and an error contract that tells the agent what to do when things go wrong. The model is not a mind reader. It is a client. Give it a spec sheet worthy of one.

What is the worst tool definition you have shipped, and what did it cost you before anyone noticed?
