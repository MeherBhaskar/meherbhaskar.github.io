---
layout: post
title: "Six Ways Agents Fail at Calling Tools, and How to Catch Each One"
description: "Most agent failures are not reasoning failures. They are tool-use failures, and they come in six distinct shapes: wrong tool, wrong arguments, malformed calls, wrong sequencing, misread results, and calls never made. Each one needs different instrumentation. Treat tool use as the reliability surface it is."
date: 2026-10-20
tags: [agents, tools, production, reliability, debugging]
---

Most practitioners get tool use wrong in the same way. They treat it as one problem. The agent "struggles with tools," so they add more tools, or better descriptions, or a bigger model, and the failure rate barely moves. That is because tool use is not one problem. It is six problems wearing one name, and each one needs a different fix. A bigger model will not fix a sequencing bug. A better tool description will not fix a result that the agent misread.

Here is the thesis: if you cannot name which of the six failure modes just happened, you cannot fix it, and you cannot measure whether your fix worked. The taxonomy below is the one I use when debugging production agents. Every tool failure I have seen fits in one of these buckets, and every bucket has its own instrumentation. Start there, and the vague complaint "the agent is unreliable with tools" turns into six measurable rates you can drive down one at a time.

## 1. Wrong tool

The agent picks a plausible tool that is not the right one. You have `search_orders` and `search_order_items`, or `get_customer` and `get_customer_history`, and the agent consistently reaches for the near neighbor. This is the failure mode most people picture when they say "tool use is broken," and it is the one most often misdiagnosed, because the tool call itself looks perfect. Valid JSON, valid arguments, successful execution, wrong answer. The trace shows no error anywhere. Only the outcome is wrong.

The mechanism is similarity, not stupidity. Tool selection is a retrieval problem over descriptions, and descriptions written by engineers read alike. When two tools overlap, the model picks by surface resemblance to the user's words, not by the operation the task actually needs. Add more tools and the collision surface grows. This is why teams that "fix" tool selection by adding a tool often make it worse: every new tool is a new near neighbor for an existing one.

The fix is disambiguation at the description level and measurement at the selection level. Write each tool description to say what it is NOT for, not just what it is for. "Searches order headers by customer or date. Does not return line items; use search_order_items for those." That negative clause does more work than three paragraphs of positive description, because it targets the exact confusion the model experiences. Then log the selection: for each task, which tool was chosen, and whether the task succeeded. A tool that is chosen often and followed by a second, corrective call is a tool whose description is losing a contest. That pattern, choose then correct, is the signature of wrong-tool failures, and it is visible only if you log the sequence, not just the single call.

## 2. Right tool, wrong arguments

The agent picks the right tool and fills it with wrong values. A missing required field. An enum value that does not exist. A date in the wrong format. An ID copied from the wrong part of the conversation. A unit mismatch, dollars where the tool expects cents, that sails through validation and returns a confident, wrong result.

This mode is insidious because half of it is silent. Malformed arguments fail loudly and get counted. Semantically wrong arguments succeed quietly. The tool returns data for the wrong customer, the wrong date range, the wrong product, and the agent builds its answer on top of it. Nothing in the trace is red. The user is the first error detector, and the user is the most expensive one.

Two mechanisms drive it. First, argument values usually come from conversation context, and context is lossy: the model must copy an identifier from turn three into a call at turn nine, across summaries, tool outputs, and its own reasoning. Copying is where agents quietly corrupt data. Second, schemas are often loose where they should be strict. A free-text field that accepts anything will accept the wrong thing. A string field for a date will accept "next Friday" and let the backend guess.

The instrumentation is argument-level validation before execution, and it has two layers. The cheap layer is schema strictness: enums instead of strings wherever the value set is closed, formats enforced at the schema level (ISO dates, not "a date"), and required fields that are actually required. The expensive layer, and the one that catches the silent half, is semantic validation: check that the ID exists, that the date range is sane, that the value the agent passed matches an entity mentioned in the conversation. Log every validation rejection with the field name and the rejected value. Within a week you will have a ranked list of the fields your agents get wrong, and that list is your prompt and schema roadmap.

```python
# Validate semantically, not just syntactically, before executing.
def validate_args(tool, args, conversation_entities):
    for field, value in args.items():
        if field.endswith("_id") and value not in conversation_entities:
            raise ArgumentError(f"{field}={value} not found in conversation")
        if field.endswith("_date") and not is_iso_date(value):
            raise ArgumentError(f"{field} must be ISO format, got {value!r}")
    return True
```

## 3. Malformed calls

The agent produces a tool call that cannot be parsed at all. Truncated JSON. A string where the schema demands a number. A nested object flattened, or a flat object nested. An argument the schema never defined. This is the noisiest failure mode and therefore the least dangerous in production, because it fails in the open. But it is the most common failure mode in one specific place: long, complex schemas.

The mechanism is straightforward. Tool-call generation is constrained decoding under pressure, and the pressure grows with schema complexity. A tool with twelve parameters, three of them nested objects, is a formatting challenge the model must solve while also reasoning about the task. The longer the output, the more chances to derail. Teams that notice this usually respond by shrinking the model or simplifying the task. The cheaper response is to shrink the schema. Split one twelve-parameter tool into two six-parameter tools. Flatten nested objects where the nesting carries no meaning. Set the schema to strict mode so the provider enforces structure instead of hoping the model does.

Instrument it as a rate, not a count: malformed calls divided by total calls, per tool. A tool with a high malformed rate has a schema problem, not a model problem. If the rate spikes for all tools at once, something changed upstream, a model migration, a prompt change, a new system instruction. That global spike is one of the fastest smoke signals you have, and it costs one counter to build.

## 4. Right call, wrong time

The agent calls the right tool with the right arguments at the wrong moment. It queries before the prerequisite call has returned. It fires two dependent calls in parallel, and the second one reads stale state. It calls a write tool twice because the first call's result arrived slowly and the agent assumed it failed. It calls a read tool after the state it needed has already changed.

This is the failure mode that separates tool use from single-turn function calling, and it is the one most tutorials ignore entirely. A tool call is not an isolated event. It is a step in a sequence, and sequences have ordering constraints, dependencies, and side effects. The agent has no native sense of any of this. It sees a list of tools and a conversation. The ordering lives in its head, and its head is a next-token predictor with no clock and no transaction log.

The fix is to make ordering explicit and cheap. Where a sequence is fixed, encode it as one tool, not three the agent must order correctly. Where ordering is genuinely conditional, state the precondition in the tool description: "Call get_cart before apply_discount. apply_discount reads the cart state at call time." And make your write tools idempotent, with a client-supplied idempotency key, so the double-call that will eventually happen is harmless instead of a duplicate charge or a duplicate record.

```python
# Idempotency turns a sequencing bug into a no-op instead of a duplicate.
def apply_discount(cart_id, code, idempotency_key):
    if existing := store.get(idempotency_key):
        return existing  # Same key, same result. No double discount.
    result = _apply(cart_id, code)
    store.set(idempotency_key, result)
    return result
```

Instrument sequencing failures by logging the call graph: which calls preceded which, which calls ran in parallel, which calls were retried. The signature of a sequencing failure is a correct call whose result contradicts the call that followed it. You will only see that signature in a trace that shows time, not in a log that shows calls one at a time.

## 5. Right call, misread result

The agent makes a perfect call, gets a perfect result, and misunderstands it. It treats an empty list as a failure and tells the user nothing was found, when the empty list was the correct answer. It ignores an error payload nested inside a 200 response and reports success. It reads the first item of a paginated result and never asks for page two. It takes a field named `total` to mean the total it wanted, when the API meant something else.

This is the failure mode I find most underrated, because it looks like a reasoning failure and gets filed as one. The team concludes the model is weak, when the actual defect is the shape of the data it was handed. Tool results are written for programs, not for language models. They are nested, abbreviated, paginated, and full of fields whose names mislead. Handing a raw API response to a model and expecting flawless interpretation is like handing a raw database dump to a new hire and expecting flawless analysis. The format is the bug.

The fix is a result contract. Every tool should return a small, shaped result: a status field that is unambiguous (`ok`, `empty`, `error`, never an empty body that could mean any of the three), the data the agent actually needs, and nothing else. Strip the forty fields the agent will never use, because every unused field is a chance to misread. Put the interpretation-critical facts first: "0 orders found for this customer in the last 90 days" beats a bare `[]` by a wide margin, because the first one cannot be misread as an error.

Instrument it by logging the agent's next action after each tool result. The signature of a misread is a correct result followed by an incorrect conclusion: a successful call followed by an apology, an empty result followed by a retry of the same call, an error payload followed by a confident answer. That pattern, result then wrong conclusion, is measurable, and it points at the tool's output format, not at the model.

## 6. Call never made

The agent never calls the tool at all. It answers from memory. It guesses the answer, or reconstructs it from conversation fragments, or says it cannot help, when the tool that would answer the question is sitting in its tool list. Sometimes it tries once, gets an error, and gives up instead of retrying with corrected arguments. Sometimes it loops, retrying the identical failing call five times, which is the same failure wearing a busier costume: the useful call was never made.

The mechanism is usually a prompt or incentive problem, not a capability problem. If the system prompt says "be helpful and answer quickly," the model optimizes for speed over accuracy and skips the call. If the tool descriptions are vague, the model cannot see why a call would help. If a previous error taught it that calling is risky, it avoids calling. And the give-up-after-one-error variant is almost always a missing instruction: nobody told the agent that a failed call is information, not a verdict, and that the correct response to a fixable error is one corrected retry, not surrender.

The fix has three parts. First, make tool use the default, not the option: "When a question can be answered by a tool, call the tool. Do not answer from memory." Second, give the agent a retry policy with teeth: one retry with corrected arguments after a validation error, then escalate to the user. Third, log the omission rate: tasks where a tool existed that could have answered the question and was not called. That rate is the single most honest measure of whether your agent is actually tool-using or just tool-adjacent. Most teams are shocked the first time they measure it.

## The instrumentation stack, in one place

Each failure mode has its own signature, and together they form the dashboard a tool-using agent deserves:

- Wrong tool: choose-then-correct sequences, per tool pair.
- Wrong arguments: validation rejections by field name, plus silent semantic mismatches caught by entity checks.
- Malformed calls: malformed rate per tool, with global spikes as the upstream-change alarm.
- Wrong time: call-graph traces showing ordering, parallelism, and retries.
- Misread results: correct result followed by wrong conclusion, per tool.
- Never called: omission rate, tasks answerable by a tool where no call happened.

Build this before you build your next tool. The taxonomy is not taxonomy for its own sake. It is the difference between "our agent is flaky with tools" and "our wrong-argument rate on the search tool is 11 percent, driven by the date field, and we know exactly which schema change fixes it." The first sentence is a complaint. The second is a work ticket. Production reliability is the process of turning complaints into work tickets, one failure mode at a time.

So here is the question I would actually ask, because it is the one that changed how I build: pick the last tool failure you debugged. Which of the six was it, really, and what would you have logged to catch the next one before your users did?
