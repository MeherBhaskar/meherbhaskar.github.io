---
layout: post
title: "The Replay Test: Record Production Traces and Replay Them Before Every Deploy"
description: "Most agent deploys are tested on fresh prompts and judged by vibes. Production already handed you the best test suite you will ever write: the traces of real requests. Record them, freeze the tool results, replay them against every candidate, and diff the outcomes. A deploy that has not survived replay is a guess, not a release."
date: 2026-10-30
tags: [agents, evals, production, regression-testing, observability]
---

Most practitioners deploy agent changes the wrong way, and the mistake is specific. They write a handful of fresh test prompts, run the new version against them, eyeball the answers, and ship when nothing looks broken. The test set is small, it was written by the same person who wrote the change, and it covers exactly the cases the author already thought about. The cases that break in production are, by definition, the ones nobody thought about. So the deploy goes out, the new prompt or model looks fine on ten curated examples, and a week later a class of real requests starts failing in a way no test ever exercised.

Here is the thesis: production already handed you the best test suite you will ever write. It is the log of real requests your agent actually served, with all their messiness intact. Record those traces, replay them against every candidate before it ships, and diff the outcomes. A deploy that has not survived replay is a guess, not a release.

## What a trace actually is

A trace is not a transcript. A transcript is the pretty rendering of a conversation, and it throws away most of what you need. A replayable trace is the full causal record of one request: the user input, the system prompt version, the model identifier and parameters, every tool call with its arguments, every tool result exactly as returned, every intermediate agent decision, and the final output. If any of those pieces is missing, you cannot replay faithfully, and you will spend the deploy review arguing about whether a difference came from your change or from a gap in the record.

Two pieces matter more than the rest. First, tool results must be recorded verbatim, not summarized. An agent that called a search tool and got back ten results with a caveat on result three behaves differently from an agent handed a clean summary of those results. If you record only the summary, your replay is testing a different agent than the one that ran in production. Second, versions must be recorded, not assumed. The prompt version, the model version, the tool schema version. When the replay diverges, the first question is always whether the difference came from your change or from the baseline shifting underneath you, and without versions recorded you cannot answer it.

This is the same discipline as event sourcing in backend systems, and it exists for the same reason. You cannot reason about a system you cannot reconstruct. A trace store is your event log. Everything else, dashboards, alerts, evals, is downstream of it.

## The replay loop, concretely

The loop has four steps, and skipping any one of them quietly invalidates the rest.

Step one: sample. You do not replay everything. Production volume makes that expensive and, more importantly, useless, because most requests are near duplicates of each other. Sample stratifically instead. Take a slice of the most common paths, because a regression there hurts the most users. Take a slice of every known failure mode, because those are the cases your change is most likely to disturb. Take a slice of the long tail, the weird inputs, the edge cases, the requests that made a human reviewer pause. And take a slice of the highest stakes paths, the ones where a wrong answer costs real money or real trust, even if they are rare. A replay set that is only the happy path is just your curated test set with extra steps.

Step two: freeze the world. Replay against recorded tool results, not live tools. This is the step teams resist, because it feels fake. It is the opposite of fake. Live tools change between the original run and the replay: inventory moves, prices move, a search index updates, an external API returns a different answer for the same query. If you replay against live tools, every diff is ambiguous. Did your change break this, or did the world move? Freezing tool results, the way HTTP tests use recorded cassettes, removes that ambiguity. You are testing one variable, your change, against a fixed world. That is what makes a diff interpretable.

There is one honest exception. Some tools are the point of the test. If your change is a new tool, or a changed tool schema, you cannot replay against the old tool's recorded results and learn anything. For those deploys, replay the frozen set for regression and run a separate live smoke set for the new capability. Mixing the two into one number is how teams ship a broken tool while pointing at a green replay score.

Step three: replay the candidate. Run the new prompt, model, or code against each recorded trace, with the recorded inputs and the frozen tool results, and capture the full new trace. Do not compare just the final answer. Compare the tool call sequence, the arguments passed, and the intermediate decisions. Two runs can reach the same final answer by different routes, and the route matters: a candidate that reaches the right answer by skipping a verification step has not improved, it has gotten luckier.

Step four: diff, and classify every difference. This is where most replay setups die, because teams dump a pile of diffs on a reviewer and call it a gate. A diff pile is not a gate. A classification is. Every difference falls into one of four buckets. Identical, no action. Improved, the new output is better by a stated criterion, and that criterion should be written down before you look at the diffs, not invented after. Regressed, the new output is worse, and this blocks the deploy until it is understood. And flake, the difference is within the noise of the model's own nondeterminism, which you measure by replaying the old version against itself.

That last bucket is the one that separates a serious replay setup from a theatrical one, because it forces you to confront the central problem of replaying language models.

## The determinism problem, honestly handled

Language models are not deterministic, even at temperature zero, and anyone who tells you otherwise has not run the same prompt a hundred times across a week of model serving. The model version drifts, the serving stack changes, floating point behavior varies across hardware. If you demand byte-identical replay, you will block every deploy forever and then, inevitably, someone will turn the gate off.

The honest approach is to stop comparing single outputs and start comparing behavior. Replay the baseline against itself, say five times per trace, and measure how much it varies. That is your noise floor. Then replay the candidate the same number of times. A candidate difference only counts as a regression if it falls outside the baseline's own variation, consistently, across runs. For decisions that matter, use a stricter standard: extract the decision from the output, did it call the refund tool or not, did it escalate or not, did it cite a source or not, and compare decisions, not prose. Prose varies. Decisions are what users feel.

This costs tokens. Five runs per trace across a sampled set is a real bill, and teams that refuse to pay it should say so plainly rather than running a single replay and calling it a gate. The cheaper alternative is real but weaker: replay once, and treat any diff as a flag for human review rather than an automatic block. That is a reasonable trade for a small team. What is not reasonable is replaying once, seeing no diffs, and declaring the deploy safe. Absence of a diff in one nondeterministic run is not evidence of anything.

## What replay catches that curated tests do not

Replay catches the failure class that matters most in production agents: regressions on real inputs you did not think to test. A prompt change that tightens refusal behavior will look perfect on your curated set and will quietly start refusing a class of legitimate requests that real users phrase in a way you never wrote down. A model upgrade that improves reasoning will look better on benchmarks and will subtly change tool call ordering on one specific workflow, skipping a check that only shows up when the tool returns an empty result. A tool schema change that renames a field will pass every unit test and will break every trace where the agent relied on the old field name in a way no test asserted.

Replay also catches something subtler: drift in the baseline itself. When you replay the old version against its own recorded traces and the outputs have moved, you have learned that the ground moved under you. The model provider shipped a new snapshot, or the serving behavior changed, or a tool's live behavior shifted in a way your frozen results now expose. Teams without replay discover this drift the same way users do, one complaint at a time. Teams with replay discover it on the next deploy review, with a trace in hand.

And replay gives you something no curated test set can: a regression test that grows for free. Every production failure, once understood, becomes a trace in the replay set. Every weird user phrasing, every adversarial input, every edge case that embarrassed you in production is now a permanent guard against the next change reintroducing it. Over months, the replay set becomes the institutional memory of everything your agent has ever gotten wrong. That is a test suite no human author could write, because no human author lived through all of it.

## What replay does not catch, and what to do about it

Replay has a blind spot, and naming it is part of using it honestly. It only tests the past. A brand new input class, a new tool, a new user population, a world that changed since the traces were recorded, none of that appears in a replay set. Replay is a regression gate, not a capability test. If you treat a green replay as proof that the new version handles new situations well, you have mistaken a rearview mirror for a windshield.

So pair it. Replay for regressions, plus a small live probe set for new capability: fresh inputs, live tools, human judged, run after the replay gate passes. And refresh the sample regularly. A replay set built from last quarter's traffic slowly becomes a museum. Retire traces that no longer reflect real usage, add traces from the newest failure modes, and reweight the sample when the product's usage shifts. A stale replay set is worse than no replay set, because it gives you confidence you have not earned.

There is also a privacy obligation that comes with the whole setup, and it is not optional. Production traces contain real user inputs, and storing them verbatim means storing user data. Sanitize before the traces enter the replay store: strip credentials, tokens, and personal identifiers, and restrict access to the store the way you would restrict access to production data, because that is what it is. A replay store with loose access controls is a data breach waiting for someone to notice. The teams that do this well treat the trace store as production infrastructure, with retention limits and access logs, not as a debug dump on a shared drive.

## The gate itself

Here is the version I would defend in a design review. Every agent deploy runs the replay gate before it ships. The gate replays a stratified sample of recent production traces against the candidate, with frozen tool results, and classifies every diff as identical, improved, regressed, or flake against a measured noise floor. Any unexplained regression blocks the deploy. Any baseline drift discovered by the self-replay is reported, even if the deploy proceeds, because drift is information the team needs regardless. The replay set is refreshed on a schedule, and every production incident adds its trace to the set.

That is it. No exotic tooling required to start. A trace store, a replay runner, and a diff classifier, even a crude one, will catch more real regressions in the first month than a curated test suite will catch in a year. The reason is simple and a little humbling: your users have already written your best tests. They wrote them by using your agent in ways you did not predict, on inputs you did not imagine, in combinations you did not design for. The only question is whether you kept the receipts.

Do you replay production traces before you deploy, or are you still testing on prompts you wrote yourself? If you run replay, what surprised you most the first time a deploy failed the gate?
