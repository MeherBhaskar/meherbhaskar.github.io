---
layout: post
title: "Engineering Reliable AI Systems: Notes from the OMS Talk Stage"
description: "I gave 'Beyond the Prototype: Engineering Agentic AI for Production' at the OMS Analytics Conference yesterday. Here is the write-up: reliability is not a property of the model, it is a property of the system around it. Four system properties that matter more than any benchmark."
date: 2026-10-10
tags: [reliability, agents, production, talks]
---

Yesterday morning I gave a talk at the Georgia Tech OMS Analytics Conference: "Beyond the Prototype: Engineering Agentic AI for Production." It went well. Four attendees messaged me on LinkedIn afterward, which is the honest metric I trust, and the questions kept coming after the session ended.

One question stuck with me. An attendee asked about how verbose agents should be: whether all that intermediate reasoning output helps or just burns tokens and confuses users. It was the best question of the session, because it is not really a question about verbosity. It is a question about what reliability means for systems that think out loud.

This post is the written version of the talk, plus the answer I wish I had given to that question. The thesis: reliability is not a property of the model. It is a property of the system around the model.

## The model is the most reliable part of your stack

Most reliability discourse about AI is model discourse. Hallucinations, benchmark scores, which model is "more reliable." I opened the talk by saying the opposite of what the room expected: the model is the most reliable component in your agent stack.

Here is what I mean. A model fails predictably. It produces a probability distribution over tokens. When it goes wrong, it goes wrong in ways that look like every other wrong output from that model, which means you can characterize the failure, instrument for it, and design around it. Its failure surface is bounded by its training.

Your system fails structurally. The agent retries a tool call that was not idempotent and double-books an order. A tool times out silently and the agent interprets silence as success. Two agents race on shared state and the second one's write wins. A third-party API returns a 200 with an error body and the agent moves on. None of these are model failures. They are ordinary distributed-systems failures, wearing an AI costume.

This is why the reliability conversation gets derailed. Teams spend months chasing a more capable model, and their production incidents keep coming from the plumbing. If your agent cannot guarantee that a retried write is safe, that an audit trail exists for every action, and that a runaway plan gets stopped before it does damage, a smarter model just fails more creatively.

## What reliable actually means for an agent

In traditional software, reliability has crisp definitions: uptime, error rates, recovery time. For agents, I think the definition is different, because the interesting failures are not crashes. An agent that runs to completion and does the wrong thing is worse than an agent that errors out. So I define reliability for agents along four system properties, and I spent most of the talk on these.

**1. Idempotency, everywhere a tool touches the world.**

Agents retry. It is in their nature: a tool call fails, the agent tries again, or tries a slightly different approach, or loops because it did not see the first result. If your tools are not safe to call twice, retries are corruption. This is not a new idea, it is database engineering from thirty years ago, but agent teams rediscover it one double-write incident at a time.

The pattern is unglamorous, which is why it gets skipped:

```python
def execute_tool(call):
    key = call.idempotency_key  # agent generates once per intent
    if store.has(key):
        return store.get(key)   # replay the recorded result, do not re-execute
    result = run_unsafe_thing(call)
    store.put(key, result)
    return result
```

Every mutating tool gets an idempotency key, generated once per intent, and the store is the source of truth for whether the world has already been changed. Reads stay cheap and keyless. Writes go through the key. This one pattern eliminates the most expensive class of agent incidents I have seen: the ones where the agent did its job twice.

**2. An audit trail, not just logs.**

Standard application logs record what happened. An agent needs something stronger: why it happened. For every action the agent takes, you need the decision (which tool, with which arguments), the evidence (what it read, from where), and the result (what came back). Not the full chain-of-thought, that is a cost and privacy sink at scale, but the decision record.

This matters for two reasons. First, debugging. When something goes wrong at 2 AM, you are not going to re-run the model and hope it shows you the same reasoning. You are going to read the record of what it decided and why, deterministically, from storage. Second, trust. Every enterprise AI deal eventually runs into the same conversation: who is accountable when the agent acts? "The model decided" is not an answer. A complete action record is.

**3. Bounded blast radius.**

The scariest agents are the ones with no speed limit. I argued on stage that every production agent needs three things before it earns real responsibility: a circuit breaker that stops it when error rates spike, a cap on the number and cost of tool calls per task, and a progressive rollout so new agent versions see 1% of traffic before 100%.

This is where the trade-off honesty matters. Blast-radius limits make demos worse. A circuit breaker interrupts the perfect run mid-flow. A call cap truncates the beautiful plan. And I told the room: if you cannot stomach watching your agent get stopped mid-task, you are not ready to ship it. Reliability engineering for agents is mostly the discipline of building guardrails you hope never fire.

**4. Humans in the right places, not everywhere.**

The lazy answer to agent risk is "put a human in the loop." A human reviewing every action is not reliability, it is a job description. The real design decision is which actions need human approval and which do not, and the honest answer is that it depends on reversibility, not on importance.

Irreversible actions get a human. Sending the email, booking the order, publishing the change: approve first. Reversible actions get an audit trail instead: reading, drafting, planning, proposing. And the interesting middle, actions that are cheap to reverse but expensive to get wrong, like editing a shared record, gets the approval UX that takes five seconds instead of five minutes. Approval latency is part of reliability too. A human gate that takes a day turns the agent into a batch job and everyone routes around it.

## The verbosity question, answered properly

Back to the best question of the session. How verbose should agents be?

My stage answer was decent. My written answer is better, because it is the same shape as every good reliability decision: verbosity is a dial, not a value.

During debugging and onboarding, maximum verbosity is a feature. When an agent is new, your users do not yet trust it, and showing the work is how trust forms. The intermediate steps are also your debugging surface, the only way to see why the agent chose what it chose while you are still tuning it.

In steady-state production, that same verbosity is a tax. It costs tokens, it costs latency, and it trains users to skim, which means they stop noticing when something is wrong. The failure mode of a verbose production agent is alert fatigue for the person watching it.

So the dial: full reasoning trace in staging and for failed runs, decision record for every run, minimal surface for the user in production. And the deeper point, which the question really earned: verbosity is not a UX preference. It is an observability decision, and it should be made by whoever owns the incident response, not whoever designed the UI.

## The sharp version

If I compress the whole talk into the one slide I would keep: stop treating the model as the reliability problem. The model is the one component whose failures you can characterize. The reliability problems are the retry storms, the double writes, the silent timeouts, the unaudited actions, and the agent with no speed limit. Reliability for agents is distributed-systems engineering with a probabilistic core, and most of the playbook already exists. Idempotency, audit trails, circuit breakers, progressive rollouts. We have known how to do this for decades. We just have to do it again, for a new kind of component, without pretending the model will save us from the system.

The talk ended with the room asking better questions than the ones I had prepared slides for. That is how I know the material works. If you were in the room, thank you for the questions. If you are building this stuff, the slides are secondary. The four properties are the talk.

What is the first thing that broke when your prototype met production? I am collecting war stories, and I have a feeling the plumbing shows up more often than the model.
