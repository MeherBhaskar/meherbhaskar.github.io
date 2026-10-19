---
layout: post
title: "The Model Changed Under You: Detecting Silent Capability Drift in Production Agents"
description: "Version pinning is necessary but not sufficient. Model providers change serving behavior, retarget aliases, and refresh snapshots without telling you. The fix is a continuously running eval canary that measures capability, not uptime: frozen task suites, per-capability scorecards, and trajectory diffs that tell you exactly what moved."
date: 2026-10-18
tags: [evals, production, agents, reliability]
---

Most agent teams treat the model as stable infrastructure. You pinned the snapshot, your evals passed on release day, you shipped. Two months later the support tickets change character. The agent starts refusing tasks it handled fine. Tool calls come back malformed in a way they never were. One specific skill quietly degrades while everything else looks identical. Nobody deployed anything. The model changed under you.

Here is the stance most teams get wrong: pinning the model version is where the reliability work starts, not where it ends. A pinned version is a label, not a guarantee. And even if the weights never move, everything around them does. If you run agents in production without a continuously running measure of capability, you are flying blind between release-day evals and user complaints. The complaints arrive last, and they arrive expensive.

I write this as someone who has watched the failure mode from the inside: a production agent that passed every gate on deploy day, drifted over weeks, and looked perfectly healthy on every dashboard we had. Uptime was green. Latency was fine. Users were not.

## The three ways drift arrives

Drift does not announce itself. It arrives through three channels, and teams typically guard against only one of them.

**1. The alias moved.** You called `model="gpt-5"` or the provider's "latest" alias because it was convenient during prototyping, and the alias got retargeted to a new checkpoint. Behavior changes overnight. This is the one everyone knows about, which makes it the one everyone underestimates in a subtly different form: migrations. Providers deprecate snapshots on a schedule, and the forced migration lands in the middle of your quarter. If your eval suite only runs at deploy time, the migration is a deploy you never tested.

**2. The same version behaves differently.** This is the channel nobody guards. Pinned snapshots have, repeatedly and observably, shifted behavior without a version bump. The weights can stay fixed while the serving stack changes: different quantization on a new GPU fleet, a routing layer that sends your traffic to a different region's build, a change in how the system prompt is concatenated, a safety layer tuned one notch tighter. Each change is individually reasonable and collectively invisible. Your pinned string is identical. Your agent is not.

**3. Your prompt was tuned to the old model's quirks.** This is the self-inflicted channel. Over months of iteration, your prompts and tool schemas accrete workarounds for specific model behaviors: a phrasing that keeps this checkpoint from over-refusing, a JSON schema strictness that matches how this checkpoint formats tool calls, few-shot examples that steer around a quirk only this checkpoint has. The prompt becomes a compiled artifact against a specific model build. When the build shifts, the workarounds stop matching. The old model rewarded X; the new one punishes it. Your system degrades not because the new model is worse, but because your system was overfit to the old one.

That third channel is why drift feels so confusing from the inside. The new model might be strictly better on public benchmarks and strictly worse on your workload. Benchmarks measure benchmarks. Your agent measures your prompt, your tools, and your tasks, composed with a model that has moved.

## Why the drift is silent

Every standard observability layer misses this. Uptime dashboards measure the serving path, not the model's judgment. Latency percentiles do not degrade when capability does. Aggregate pass rates on a smoke test hide capability-specific movement: instruction following drops six points, tool-call formatting improves four, the average barely twitches, and the one capability your users actually depend on is the one that fell.

User ratings lag by days and confound capability with everything else: the user changed their prompt, the task got harder, the data changed. By the time a trend is visible in ratings, you have been serving degraded behavior for a week and you still cannot name what broke.

The fix is not more dashboards of the same shape. It is a different instrument: a continuously running measure of capability, sampled from the same workload your users produce, scored on the dimensions that matter.

## The eval canary

The pattern that works is borrowed from canary deployments and adapted for a dependency whose changelog you do not control.

**A frozen canary suite.** Keep a small, fixed set of tasks, thirty to eighty, that covers the capabilities your agent actually depends on: instruction following under conflicting instructions, tool calling with adversarial schemas, refusal behavior on your specific risk cases, format adherence, domain skills, multi-step planning. Small enough to run nightly, representative enough that a regression in any covered capability hurts. Freeze it. The suite's value is that it does not move, so movement in the scores means the model moved. Resist the urge to tune the suite to make scores look good; a canary you game is a canary that dies quietly.

**Per-capability scorecards, never a single scalar.** Score each capability separately and track each one as its own time series. The single scalar is where drift goes to hide. A six-point drop in tool-call reliability buried inside a flat aggregate is exactly the failure mode that produces "nobody deployed anything" incidents. Ten small numbers beat one big one.

**Nightly runs against the production config.** Same model string, same system prompt, same tools, same temperature. Run the canary every night and after every config change. This turns "the model changed under you" from a mystery into a dated event: scores were stable through Tuesday, instruction following dropped Wednesday night, and you have the timestamp.

**Compare distributions, not point estimates.** A single night's score is noise. Flag a capability only when it moves outside its control band for two consecutive runs. The implementation can be simple: track a rolling mean and standard deviation per capability over the last N clean runs, and alert when the new score falls more than two standard deviations below the mean twice in a row. Sophistication is optional; consistency is not. The point is a rule that fires on sustained movement and stays quiet on noise, applied identically every night.

**Trajectory diffing.** When the canary fires, the score tells you something moved; the trace tells you what. Keep the full trajectories from a known-good baseline run, and diff new failures against them step by step. The diff usually names the mechanism immediately: the model now calls the search tool before reading the provided context, or it started wrapping JSON arguments in markdown fences, or it began refusing a class of requests the old build handled. Without the diff you get a score drop and a guessing game. With it you get a one-line diagnosis.

**Shadow-scoring production traces.** The canary covers what you thought to test. Sample a fraction of real production trajectories and score them with your judge suite offline. This catches drift in task shapes your canary does not cover, and it is the only instrument that sees how the model behaves on your actual distribution rather than your imagined one.

## A drift gate, concretely

The pattern is small enough to sketch. The core is a nightly job that runs the frozen suite against the live config, compares per-capability scores against control bands, and fails loudly on sustained regression:

```python
# drift_gate.py: nightly capability-drift check for a production agent
import json, statistics, sys
from datetime import date

CANARY_SUITE = "evals/canary/v3.jsonl"   # frozen: never edit, only version
HISTORY = "evals/canary/history.jsonl"   # one record per nightly run
CLEAN_WINDOW = 14                        # rolling baseline of known-good runs
BREACH_STDEV = 2.0

def run_canary_suite():
    # Run every task in the frozen suite against the CURRENT production
    # config: same model string, system prompt, tools, temperature.
    # Returns {capability: score_0_to_1}.
    ...

def control_bands(history):
    bands = {}
    for capability in history[0]["scores"]:
        series = [r["scores"][capability] for r in history[-CLEAN_WINDOW:]]
        mean = statistics.mean(series)
        sd = statistics.pstdev(series) or 1e-6
        bands[capability] = (mean - BREACH_STDEV * sd, mean)
    return bands

def main():
    scores = run_canary_suite()
    history = [json.loads(l) for l in open(HISTORY)]
    bands = control_bands(history)

    breached = [c for c, s in scores.items() if s < bands[c][0]]
    # Require two consecutive breaches before alerting: one is noise.
    prior = set(history[-1].get("breached", []))
    sustained = sorted(set(breached) & prior)

    history.append({
        "date": str(date.today()),
        "scores": scores,
        "breached": breached,
    })
    json.dump(history[-1], open(HISTORY, "a"))
    open(HISTORY, "a").write("\n")

    if sustained:
        print(f"DRIFT ALERT: sustained regression in {sustained}")
        print("Diff failing trajectories against the last clean baseline")
        print("before touching prompts or tools.")
        sys.exit(2)
    print("canary green:", {c: round(s, 3) for c, s in scores.items()})

if __name__ == "__main__":
    main()
```

Two details matter more than the code. First, the consecutive-breach rule: single-night movement is noise, and a gate that pages on noise gets muted, which is worse than no gate. Second, the failure message points at the trajectory diff, not at prompt tuning. When the canary fires, the first question is "what did the model start doing differently," not "how do we prompt around it." Answer the first question before you touch anything, or you will tune your system to a moving target.

## When drift fires

Have the runbook written before you need it. The sequence that works:

1. **Confirm it is the model, not you.** Check that nothing in your config changed: prompt, tools, temperature, routing. The canary runs against the production config precisely so a config change shows up as a same-night event with an obvious cause.
2. **Bisect the capability.** The per-capability scorecard tells you which dimension moved. Pull the failing trajectories and diff them against the baseline. Name the mechanism in one sentence.
3. **Decide: adapt or retreat.** If the provider offers the previous snapshot, rolling the alias back buys time. If not, you adapt: retune the prompt or tool schema for the new behavior, add the failing task shapes as permanent regression cases in the canary, and record what changed in a model-changelog note of your own, since the provider will not write one for you.
4. **Shrink the overfit.** Every workaround the incident reveals is a prompt that was compiled against a specific model build. Replace quirk-specific phrasing with behavior that is robust across builds: stricter schemas instead of pleading prose, validation and retry instead of hoping the format holds. Each incident is an audit of how much of your system was accidentally model-specific.

The deeper move is organizational: treat the model the way you treat any external dependency with breaking changes. You would not upgrade a database without running your test suite. A model whose behavior shifts under a pinned version string is a dependency upgrade you did not schedule. The canary is your test suite for it.

## The thesis

Your eval suite is a contract with the model: these are the behaviors we depend on, measured on tasks we chose. When the model changes, the provider renegotiates that contract without telling you. Most teams find out from their users, weeks later, in the form of complaints they cannot diagnose. The teams that do not are the ones running the canary every night, watching ten small numbers instead of one big one, and diffing trajectories the morning something moves. Pin the version. Then assume the pin is a rumor, and verify it daily.

What is the smallest capability in your agent that, if it silently degraded six points, would cost you the most before anyone noticed? That is your first canary task.
