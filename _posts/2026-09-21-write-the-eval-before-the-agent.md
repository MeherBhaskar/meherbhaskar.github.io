---
layout: post
title: "Write the Eval Before the Agent"
description: "Test-driven development for agents: the eval set is the specification. Writing it first changes what you build."
date: 2026-09-21
tags: [evals, engineering]
---

Test-driven development has a simple insight: writing the test first forces you to define "working" before you are emotionally invested in an implementation. The same discipline applies to agents, with higher stakes, because agent behavior is harder to specify and easier to fool yourself about. Write the eval before the agent.

This is not about testing methodology. It is about what the act of writing the specification does to your thinking, and how it changes the thing you end up building.

## The TDD analogy, and where it holds

In traditional TDD, you write a failing test, make it pass, refactor. The test is a precise, executable specification of behavior. For agents, the analogy holds in structure but the "test" is fuzzier: a set of realistic tasks with judged outcomes, not assertions on return values.

What carries over is the sequencing effect. When you write the eval first, you are forced to answer questions that implementation-first development lets you dodge: What exactly should the agent do here? What does a good output look like, concretely? What are the acceptable failure modes? How will we know?

These sound like questions with obvious answers. They are not. The first time you try to write down what "correct" means for a realistic agent task, you discover the task is fuzzier than you thought. That discovery is the value. It is much cheaper to discover fuzziness in a document than in production.

What does not carry over is the tight red-green loop. Agent evals are slower, noisier, and more expensive to run than unit tests. You will not get the minute-by-minute rhythm of TDD. What you get instead is a slower version of the same discipline: define, attempt, measure, adjust. The loop is longer, but the direction is the same.

## Eval-first clarifies scope

Here is what actually happens when a team writes evals first. They sit down to specify twenty representative tasks, and by task six they are arguing about scope. Is this request in or out? Should the agent handle the ambiguous version or ask a clarifying question? What about the request that is technically in scope but requires a tool we have not built?

This argument is the most valuable meeting the team will have, and eval-first forces it to happen before any code exists. Implementation-first teams have the same argument six weeks later, except now it is about whether to rip out a subsystem, and now egos are attached to the implementation.

The eval set becomes the scope document. Not a vague product brief, but twenty or fifty concrete cases that say: this is what we handle, this is what good looks like, this is where we draw the line. When scope debates recur, and they will, you point at the cases instead of relitigating principles.

## Failing evals drive honest iteration

Once the evals exist, iteration becomes honest. You run the set, you see what fails, you fix the failures. This sounds trivial, but compare it to the alternative: building the agent, trying a few prompts by hand, declaring it good. The eval-first loop replaces vibes with measurement at every step.

It also changes what "done" means. Without evals, done is a feeling: the demo looked good, the team is tired, ship it. With evals, done is a number: the set passes at the target rate, on the cases that matter, with the failure modes understood. Feelings lie. Numbers can lie too, but they lie more slowly and leave evidence.

There is a discipline hidden here that most teams skip: do not ship until the spec passes. The eval set is the specification you wrote for yourself. If the system does not meet it, the system is not done, no matter how good the demo looks. Every team nods at this. Few enforce it when the deadline looms. The ones that do ship systems that survive.

## When the eval is the hard part

Sometimes writing the eval is harder than building the agent. The task is genuinely ambiguous, reasonable people disagree on correct outputs, or judging requires expertise you do not have in-house.

This is information, not an obstacle. If you cannot specify what correct looks like, you cannot build a system that is reliably correct. The difficulty of the eval is telling you something about the difficulty of the task, and you should listen.

Three moves for hard evals. First, narrow the scope until the eval is writable, then expand deliberately. A small, well-specified eval beats a large, hand-wavy one. Second, invest in judging: rubrics, calibrated LLM judges, sampled human review. The judge is part of the spec, and a sloppy judge is a sloppy spec. Third, accept partial specification honestly. Some aspects of quality resist formalization. Say which ones, measure what you can, and do not pretend the unmeasured parts are covered.

The worst response to a hard eval is to skip it and build anyway. That is how you get a system whose behavior nobody can describe, evaluated by nobody, shipping on confidence.

## It changes the architecture

Here is the deepest effect, and the reason this is more than a testing practice. Writing evals first changes what you build, not just how you test it.

When the spec exists before the implementation, architecture decisions get made against it. You choose the retrieval strategy because the evals demand certain context quality. You add the validation step because the evals include adversarial tool outputs. You simplify the chain because the evals show where errors compound. The evals are not a harness around the system. They are the blueprint the system was built from.

Implementation-first teams build the architecture that was easiest to imagine, then discover through painful iteration what the task actually required. Eval-first teams discover the requirements up front, in the cheap medium of specification, and the architecture follows.

## Answering the objections

Every team that hears "write the eval first" raises the same objections. They sound reasonable. They are mostly wrong.

**"It is too slow."** Writing evals feels slower than building because building produces something you can demo and evals produce a document. But the time is not extra, it is moved earlier, where it is cheapest. The scope argument you have during eval writing takes an afternoon. The same argument during implementation takes a sprint and someone's morale. Measure the full cycle, not the first week.

**"The task keeps changing."** Then your evals should change too, and the fact that they need changing is valuable signal. An eval set that keeps breaking is telling you the task is unstable, which is something you should know before you pour implementation effort into it. Stable tasks get stable evals. Unstable tasks get early warning.

**"We will write evals after launch."** No, you will not. After launch there is always something more urgent: the incident, the customer request, the next feature. Evals written after launch are written never, or written hastily to justify what was already shipped. The discipline only works if it comes first, because first is the only time with no competing urgency.

**"Our task cannot be evaled."** Then say so explicitly, and say what you are doing instead. Sometimes the honest answer is that the task is exploratory and the right move is a tight human-in-the-loop pilot, not an eval set. That is a legitimate position. What is not legitimate is building without evals while pretending the task is well understood. If it cannot be evaled, admit the uncertainty and design for it: heavy human oversight, narrow scope, fast feedback loops.

## The discipline

Write the eval before the agent. Define "working" before you are invested in an implementation. Let the spec clarify the scope, drive the iteration honestly, and shape the architecture. Do not ship until the spec passes.

It is slower at the start. It is faster everywhere else. And it is the difference between a system you understand and a system you hope about.

What would your eval set say about the agent you are building right now?
