---
layout: post
title: "The Second Agent Is the First Refactor"
description: "Every multi-agent system starts as one agent doing everything. The moment it starts failing in ways you cannot explain, you are not looking at a prompt problem. You are looking at a refactor problem. The seams that tell you one agent should become two, and how to split the work without breaking the contract between them."
date: 2026-11-21
tags: [multi-agent-systems, agents, orchestration, ai-engineering, production-ai, refactoring]
---

Every multi-agent system starts as one agent doing everything. It reads the request, plans the work, calls the tools, checks the result, formats the answer. It works in the demo. Then it grows. One more tool, one more branch in the instructions, one more edge case handled inline. And at some point it starts failing in ways you cannot explain. The failures are not wrong, exactly. They are weird. The agent does the right thing for the wrong reason, or the right thing in the wrong order, or two right things that contradict each other. You stare at the trace and you cannot find the bug, because there is no bug. There is a shape problem.

Here is the thesis: the second agent is the first refactor. Splitting one agent into two is not a scaling move or an architecture fashion statement. It is the same operation as extracting a function from a method that got too long, and it happens for the same reason. A single unit of behavior has grown past the point where one set of instructions can hold it together.

Most practitioners get this wrong in both directions. Some split too early, carving a clean single agent into a committee of specialists that spend more tokens talking to each other than doing the work. Others refuse to split at all, and end up with a 4,000 token system prompt that reads like a legal document and behaves like one too: internally inconsistent, interpreted differently on every run, and impossible to change without breaking something nobody can name.

## What a single agent can actually hold

Start with the mechanism. An agent is not a program with branches. It is a language model reading a set of instructions and a pile of context, then choosing the next action. Everything it must keep in mind at once lives in the same working memory: the goal, the plan, the tool descriptions, the conversation history, the results so far, the format rules, the edge cases. There is no separate stack frame for each concern. Every concern competes for the same attention.

When the agent has one job with one success criterion, attention is cheap. When you add a second job with a different criterion, the two start fighting. The prompt says "be thorough" and also "be fast." It says "ask the user when uncertain" and also "never block on clarification." These are not instructions. They are contradictions with polite formatting, and the model resolves them differently every run.

That is why the failures feel weird. The agent did not misread a tool result or hallucinate a fact. It resolved a contradiction in a way you did not predict, because the contradiction was never visible to you. You wrote each instruction on a different day, for a different reason, and never noticed they conflict. The trace looks fine step by step. The outcome is wrong in a way that has no single cause.

The tell is not a specific error. It is a pattern: the agent's behavior becomes non-local. A change to the formatting rules changes the tool selection. A new edge case in step three makes step seven worse. You fix one failure and a different failure appears, in a part of the behavior you did not touch. That is the signature of a unit that has exceeded its capacity. The instructions have become coupled in ways you cannot see, because they share a single attention budget and a single implicit priority order.

## The seams: where one agent becomes two

So how do you know where to cut? Not by org chart, and not by tool count. A split is justified by a seam in the behavior, and seams have recognizable shapes. Here are the ones I have learned to trust.

The first seam is a different success criterion. If part of the agent's job succeeds when the answer is correct, and another part succeeds when the answer is safe, fast, or cheap, those are two jobs. Correctness and latency do not just trade off. They demand different attention. An agent that must produce the right answer and also decide how long to keep trying is holding two criteria that fight on every step: keep searching, or stop and answer. Split the worker from the judge of "good enough," and each one gets a single criterion it can actually optimize.

The second seam is a different failure policy. Ask what happens when this part fails. If one part should retry and try a different tool, while another part should stop immediately and escalate to a human, those are two jobs. A single agent with two failure policies will apply the wrong one half the time, because the policy is a mood, not a branch. Separate the part that tries from the part that decides when trying has failed.

The third seam is a different context need. If part of the work needs the full conversation history and the other part needs only the current task and a clean slate, that is a seam. The classic example is research versus synthesis. The researcher needs the messy history, the half-formed questions, the dead ends. The synthesizer needs the findings, not the process that produced them. Forcing both into one context means the synthesizer sees noise that changes its output, and the researcher sees formatting rules that constrain its exploration. Split them, and the handoff becomes a filter: only the findings cross the seam, not the mess.

The fourth seam is a different rate of change. If one part of the behavior changes weekly (the tools, the data sources) and another part changes quarterly (the tone, the output contract), that is a seam. Every change to the tools is a chance to break the output contract. Splitting lets each part change at its own pace, with the contract between them as the only thing that must stay stable.

The fifth seam is the one most people miss: a different owner. If the person who can answer "is this behavior correct?" for the planning logic is not the person who can answer it for the output formatting, you have two agents pretending to be one. The split makes the ownership real.

A single seam is enough. Two seams is a strong signal. Three means you are already late.

## The contract is the whole job

Splitting is easy. Splitting well is the whole job, and the whole job is the contract.

When you split an agent, you are replacing implicit shared context with an explicit interface. Before the split, agent A and agent B were the same mind: they shared everything, including the stuff they should not have shared. After the split, the only thing that crosses the boundary is what you put in the handoff. That is the power of the split, and it is also the risk. A bad contract is worse than no split at all, because now the failure is silent. The first agent hands off something ambiguous, the second agent interprets it confidently, and the error compounds across the boundary with no trace to show where it entered.

So design the contract first, before you write either agent's prompt. The contract has three parts, and all three are mandatory.

First, the input schema: exactly what the second agent receives, in what shape, with what fields required and what fields optional. Not "the research findings." A named structure: the question as stated, the facts found with their sources, the confidence of each fact, the open questions that could not be answered. If a field matters, it is in the schema. If it is not in the schema, it does not cross the seam.

Second, the success criterion: what "done" means for the receiving agent, stated as a checkable condition, not a vibe. "Produce a summary the user can act on" is not a criterion. "Produce a summary that names the decision, the evidence for it, and the one open question that could change it" is a criterion. The receiving agent should be able to tell whether it succeeded without asking the first agent what it meant.

Third, the failure protocol: what the receiving agent does when the input does not satisfy the schema, or when its own work fails. Does it ask the first agent to redo the work? Does it escalate to the user? Does it produce a partial answer with the gap marked? This is the part everyone skips, and it is the part that decides whether a split makes the system more robust or just moves the failure to a place where it is harder to see.

Here is a concrete shape for the contract, in the form most teams actually need. Two agents: a researcher and a synthesizer. The researcher gets the user request and the tools. The synthesizer gets only the researcher's output, never the raw conversation. The handoff schema is a short JSON object: the question, a list of findings (each with a source and a confidence), and a list of open questions. The synthesizer's success criterion is an answer that names the decision, the evidence, and the open question. Its failure protocol is to return a partial answer with the gap marked, never to go fetch more data itself, because fetching is the researcher's job and the split exists precisely to keep that boundary clean.

```json
{
  "question": "Which warehouse should fulfill this order?",
  "findings": [
    {"fact": "Warehouse A has 40 units in stock", "source": "inventory API, 09:41", "confidence": "high"},
    {"fact": "Warehouse B has 12 units in stock", "source": "inventory API, 09:41", "confidence": "high"}
  ],
  "open_questions": ["Does the order require same-day delivery?"]
}
```

Notice what is not in the handoff. No conversation history. No tool-call traces. No reasoning about why the researcher chose one source over another. The synthesizer does not need it, and giving it to the synthesizer would let the synthesizer second-guess the researcher on evidence it cannot evaluate. The seam is a filter, and the filter is the point.

## What the split buys you, and what it costs

The benefit is legibility. Each agent has one job, one criterion, one failure policy. When it fails, the failure has a location. The researcher failed, or the synthesizer failed, or the contract between them failed. You can look at the handoff and see which one. That is the difference between debugging and guessing.

The benefit is also change. You can rewrite the researcher's prompt without touching the synthesizer, as long as the contract holds. You can swap the model behind one agent without swapping the other. You can eval each agent separately, with a golden set that tests its actual job instead of the whole system's behavior at once. The eval for the researcher tests whether it finds the right facts. The eval for the synthesizer tests whether it turns facts into a usable answer.

The cost is real too, and honest accounting means naming it. Two agents means two model calls, which means more latency and more tokens. The handoff itself is a serialization step: the first agent must compress its understanding into the schema, and compression loses information. If the schema is too narrow, the second agent works with a crippled view of the problem. If the schema is too wide, you have not split anything, you have just added a middleman. The split also creates a new failure mode that did not exist before: contract drift, where one agent's output slowly stops matching the other's expectations, and nobody notices because each agent's own eval still passes.

Do not split by default. Split when a seam is visible and the cost of not splitting is already being paid in weird, non-local failures. A single agent that works is better than two agents that talk past each other. The split is a refactor, and refactors are justified by pain, not by aesthetics. If you cannot name the seam, you do not have one yet.

## How to split without breaking the running system

The mechanics of the split matter as much as the decision. Do it in the wrong order and you break a working system to build a better one that does not work yet.

First, write the contract and the evals for it before you touch the agent. The contract is the spec. The evals are the test that the split preserves behavior. If you cannot write a golden set for the handoff, you do not understand the seam well enough to cut there yet.

Second, split by extraction, not by rewrite. Take the existing agent, and carve out one seam. The rest of the agent stays exactly as it is. The extracted piece becomes the second agent. The original agent becomes the first agent plus a call to the second. This is the same discipline as extracting a function: the behavior does not change, only the structure does. If the behavior changes at the same time as the structure, you cannot tell which change broke it.

Third, run both versions against the same eval set, and compare the failures, not just the pass rates. A split that keeps the pass rate but changes which cases fail has moved the risk, not reduced it. Contract failures mean the schema needs work. Capability failures mean the seam was in the wrong place.

Fourth, make the contract observable. Log the handoff on every run, in the same trace as the rest of the system. When a user reports a bad outcome, the first question should be: what crossed the seam? If you cannot answer that from the trace, the split has made debugging worse, not better.

Finally, accept that the split is not permanent. Seams move. The researcher and the synthesizer may merge again when the tools get better, or split further when a new concern appears. The point of the refactor is not to reach a final architecture. It is to keep the structure matched to the behavior, so that at any given moment, each agent holds one job it can actually hold.

That is the discipline. One agent, one job, one criterion, one failure policy. When the behavior outgrows that, do not add another paragraph to the prompt. Add another agent, cut at the seam, and write the contract like it matters, because it is the only thing holding the two halves together.

What seam have you been ignoring in your own agent? The one where a change in one place keeps breaking something somewhere else, with no visible connection between the two?
