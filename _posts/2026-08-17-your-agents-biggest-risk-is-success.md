---
layout: post
title: "Your Agent's Biggest Risk Is Success"
description: "Success brings scale, adversarial users, cost explosions, and expectation inflation. Design for the success case."
date: 2026-08-17
tags: [production, scale]
---

Everyone designs for launch. Almost nobody designs for what happens when it works. The demo goes well, the pilot expands, usage climbs, and then the system meets the success case it was never built for. Traffic a hundred times the demo. Users who probe every boundary. Costs that scale with success. Expectations that ratchet up with every win.

Failure gets all the planning. Success gets none of it, and success is the harder problem.

## The thundering herd

Agent systems have a load profile that traditional services do not. A single user request can fan out into a dozen model calls, several tool invocations, and a chain of agent handoffs. Multiply that by a traffic spike and you do not get linear degradation, you get a cliff.

The failure mode has a name from distributed systems: the thundering herd. Many concurrent requests hit shared resources at once: the same vector database, the same rate-limited API, the same model endpoint with its concurrency cap. Each individual request is fine. Together they saturate the shared layer, latencies spike, timeouts cascade, retries multiply the load, and the system falls over in a way that looks nothing like any single-request test ever showed.

You cannot find this with unit tests or golden sets. You find it with load testing that mirrors real concurrency patterns, including the bursty, correlated kind where many users do the same thing at the same time. If you have never watched your agent system under 100x demo load, you do not know what happens at 100x demo load, and hoping is not a capacity plan.

Build headroom deliberately. Know your bottlenecks before traffic finds them: which tool is rate-limited, which step is slowest, where the queue forms. And design degradation, not just scaling. When load exceeds capacity, what sheds first? A system that answers slowly for everyone is worse than one that answers fast for most and queues the rest honestly.

## Adversarial users are a certainty at scale

At demo scale, your users are colleagues and friendly pilot customers. They want the system to work. At real scale, some fraction of users want to see what it does when it does not. They probe boundaries, try to extract internals, feed it hostile inputs, and share whatever they find.

This is not a hypothetical. It is a function of audience size. With a hundred users, the curious tinkerer is rare. With a hundred thousand, there are hundreds of them, and the clever ones publish their findings, which teaches the merely curious. Scale converts rare behaviors into guaranteed ones.

Design for this from the start: least-privilege tool access, confirmation before irreversible actions, output validation, rate limits per user, abuse detection on patterns rather than individual requests. None of this is exciting work. All of it is the difference between a system that survives its own popularity and one that becomes a cautionary tale.

And assume your system prompt, your tool definitions, and your behavioral quirks will become public knowledge. At scale, they will be extracted and posted somewhere. Build as if the internals are already known, because eventually they are.

## Costs that scale with success

The cruelest success problem is economic. Your agent costs some amount per task. At demo scale, the total is a rounding error. At success scale, it is a budget line that someone important starts asking about.

Worse, agent costs often scale superlinearly with the things success brings. More users means more diverse requests, which means lower cache hit rates. Heavier usage means longer conversations, which means bigger contexts. Power users push the system harder per request than casual ones. The cost per task at scale is not the cost per task in the demo. It is higher, sometimes much higher.

This is why cost controls have to survive success, not just launch. Per-user rate limits, cost budgets per task with graceful degradation when exceeded, routing that sends easy requests to cheap models, caching that actually works under diverse traffic. And honest unit economics reviewed regularly: what does a task cost now, what did it cost last quarter, where is the trend going?

The nightmare scenario is the successful product that loses money on every task and cannot raise prices because the market was set during the cheap demo phase. Price and architecture have to be designed together, against the success case, not the pilot.

## The expectation treadmill

Here is the subtlest one. Every success raises the bar. The agent handles the easy cases, so users bring harder ones. It gets those right, so they bring stranger ones. The frontier of "what the agent should handle" advances with every win, and the system is perpetually facing the cases it is worst at.

This is actually a sign of health, but it breaks teams that planned for a fixed target. The eval set from launch day describes a world that no longer exists. The architecture that handled the pilot buckles under the sophisticated usage the pilot created. You are not done when it works. You are done never, because working changes the job.

Plan for the treadmill explicitly. Keep evolving the eval set toward the current frontier, not the launch frontier. Instrument where users are pushing hardest and let that drive the roadmap. And set expectations with stakeholders: the system's job description will keep changing, and that is the price of it working.

## Success changes the team, too

The technical dimensions get the attention, but success breaks the team as well. A system with a hundred users generates a manageable trickle of issues. The same system with a hundred thousand generates a firehose: support tickets, edge cases, incident pages, feature requests from users who now depend on it.

The on-call burden is the sharpest edge. Agent systems fail in weirder ways than traditional services, which means incidents take longer and demand more judgment. If your team designed for a quiet pilot, the first real incident wave will exhaust them. Burnout is a scaling problem, and it compounds: tired engineers make worse decisions during the incidents that tired them.

Hiring lags success by months. You cannot hire your way out of a spike that is happening now. So the team you have at launch is the team that handles the success case, at least at first. That means runbooks, not heroes. If only one person understands the orchestration layer, you do not have a system, you have a single point of failure with a name.

And the roadmap gets hijacked. Every success creates stakeholders, and every stakeholder has a request. The team that was building toward a vision spends its time servicing the success: custom integrations, urgent fixes for important customers, features that matter to the loudest users rather than the most users. This is not mismanagement, it is physics. Plan for it by protecting some fraction of engineering time for the architecture, or the success will eat the future.

## Designing for the success case

The throughline: ask "what breaks if this works 100x better than the demo?" at design time, for every dimension. Load: what saturates first? Adversaries: what gets probed? Cost: what does the invoice look like? Expectations: what will users ask for next?

None of these have perfect answers in advance. But asking the questions changes the architecture: you add the rate limiter, you scope the tool permissions, you build the cost dashboard, you version the eval set. Each is cheap at design time and expensive as a retrofit.

Most systems are designed for the demo and retrofitted for reality. The retrofit is where the outages, the incidents, and the rewrites live. Design for success and the retrofit never has to happen, because the success case was the plan all along.

What broke in your system the first time it actually worked?
