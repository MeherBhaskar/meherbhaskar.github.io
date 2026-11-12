---
layout: post
title: "The Retry Budget: Why Unbounded Agent Retries Are a DoS Attack on Yourself"
description: "Every agent retry looks cheap in isolation: one more model call, one more tool attempt. In production the retries compound into a cost and latency DoS you inflict on yourself, and the retry loop itself becomes the failure mode. A retry is a bet that the next attempt will succeed where this one failed. Most retry policies never ask whether that bet is worth making, or when it stops being one. How to design retry budgets with teeth: per-attempt caps, total budgets, failure-class routing, and the discipline to fail loudly instead of retrying quietly."
date: 2026-11-11
tags: [agents, retries, reliability, cost, latency, production-ai]
---

Most agent code retries the same way most people apologize: automatically, without thinking, and one too many times. A tool call throws a timeout. The framework catches it, waits two seconds, and tries again. The model returns a malformed JSON blob. The parser retries with a "please fix your output" nudge. The downstream API returns a 500. The agent loops. Each individual retry looks reasonable. Each one is a small, cheap, defensible decision. Add them up across a multi-step agent run and you have built yourself a denial-of-service attack with extra steps, aimed at your own wallet, your own latency budget, and your own users.

Here is the thesis: a retry is a bet, and most agent systems place that bet with no odds, no stake limit, and no one watching the table. A retry policy without a budget is not resilience. It is the absence of a decision.

## The math nobody does

Take a mundane agent run. Ten tool calls, each with a 5 percent chance of a transient failure, each retried up to three times with exponential backoff. That sounds conservative. Now run the numbers on what the tail looks like.

If each step fails 5 percent of the time and you allow three attempts per step, the chance a given step exhausts its retries is 0.05 cubed, or 0.0125 percent. Tiny. But the chance that at least one step in ten needs a retry is about 40 percent. So nearly half your runs pay for retries. And the runs that do retry pay more than one retry: a step that fails twice costs three attempts, and the backoff between them, 2 seconds, then 4, then 8, stacks directly onto user-facing latency. A run that should take 30 seconds takes 90. A run that should cost 40 cents costs a dollar twenty. And that is the good case, where the failures are genuinely transient and independent.

They usually are not independent. That is the part that turns a retry policy from a tax into a disaster.

## Correlated failure is the default, not the exception

Transient failures in textbooks are independent coin flips. Transient failures in production are weather. When an upstream API is degraded, it is degraded for every call your agent makes, for minutes at a time. When your agent hits a rate limit, the next attempt hits the same limit, only now it arrives with the rest of the queue behind it. When a tool returns a malformed response because the data it read is itself broken, retrying the tool reads the same broken data and returns the same malformed response, slower.

This is the first thing most retry policies get wrong: they treat the retry as if the world will have changed by the time the next attempt runs. Sometimes it will. A network blip clears in a second. But the failures that actually hurt in agent systems are the sticky ones: rate limits, degraded dependencies, bad inputs, poisoned state. Retrying a sticky failure does not fix it. It converts a fast, cheap, diagnosable failure into a slow, expensive, invisible one. The user does not see "the inventory service returned a 429." They see a spinner for two minutes, then a generic error, then a bill for twelve model calls that accomplished nothing.

Worse, retries amplify the very condition they are trying to survive. An agent under rate limiting that retries aggressively is a retry storm: it adds load to the exact service that is already telling it to stop. The classic backoff exists precisely because of this, but backoff only helps if the retries are bounded and the bound is small. Three retries with a 2 second base delay is not a policy. It is a hope with a timer attached.

## The retry loop is a failure mode, not a safety net

There is a second, subtler problem, and it is specific to agents. In a normal service, a retry is a retry of the same operation. In an agent, a retry is often a retry of a decision. The model tried a tool call with bad arguments. The call failed. The framework retries the call, or the model tries again with slightly different arguments, and then again, each time burning a full model call to regenerate a plan that was wrong in the first place. The agent is not recovering from a transient fault. It is arguing with a wall, and each round of the argument costs a model call.

I have seen this pattern in traces more times than I can count. The shape is always the same: the same tool, the same bad argument, the same error message, three to five times, and then the agent either gives up or, worse, switches to a different tool and starts failing in a new way. The trace is long, the cost is high, and the root cause is visible in the first three lines if anyone bothers to read them. The retry loop hid the real failure, which was that the agent did not understand what the tool wanted, and it hid it behind a wall of identical attempts that looked like progress because the token counter was moving.

This is the honest trade-off nobody writes down. Retries buy you recovery from transient faults at the price of delayed diagnosis of real faults. Every retry you allow is time during which a genuine bug, a bad argument, a misunderstood schema, a poisoned input, gets to masquerade as bad luck. The longer the retry budget, the longer the masquerade.

## What a retry budget with teeth looks like

So what do you do instead? You treat retries the way you treat any other scarce resource: you budget them, you classify what they are allowed to spend on, and you make the spending visible.

First, separate failure classes before you retry anything. Not all errors are retryable, and the distinction is not a judgment call, it is a property of the error. A timeout on a network call is retryable. A 429 with a retry-after header is retryable, once, after the stated delay. A 400 caused by a malformed argument is not retryable, ever: retrying the same bad argument is a definition of insanity with a cloud bill attached. A validation error from your own parser is not retryable at the tool level at all, it is a signal that the model needs different instructions, not another attempt. Write this down as a table, in code, not in a comment. The table is the policy. If an error class is not in the table, it does not get retried.

```python
RETRYABLE = {
    "timeout":        {"max_attempts": 2, "base_delay_s": 1.0},
    "rate_limited":   {"max_attempts": 2, "base_delay_s": 5.0, "respect_retry_after": True},
    "server_error":   {"max_attempts": 2, "base_delay_s": 2.0},
    "connection_reset": {"max_attempts": 2, "base_delay_s": 1.0},
}
# Everything else: bad_request, validation_error, auth_error,
# not_found, schema_mismatch. Zero retries. Fail loudly.
```

Two attempts, not three, not five. Two is enough to absorb a genuine blip and small enough that a sticky failure dies fast. The number matters less than the fact that it is small, explicit, and enforced in one place.

Second, cap the total retry budget per run, not just per step. A per-step cap of two retries across a ten-step run still allows twenty wasted attempts. A run-level budget says: this run gets, say, five retries total, across all steps, and when they are spent the run fails. This is the difference between a policy and a wish. The run-level budget forces the question that matters: is this run healthy enough to keep spending on? A run that has already burned four retries on two different tools is telling you something. Listen to it.

```python
class RetryBudget:
    def __init__(self, total: int = 5):
        self.remaining = total

    def spend(self, error_class: str) -> bool:
        policy = RETRYABLE.get(error_class)
        if policy is None:
            return False          # not retryable, fail now
        if self.remaining <= 0:
            return False          # budget spent, fail now
        self.remaining -= 1
        return True
```

Third, make the retry visible in the trace and in the user-facing surface. Every retry should be a first-class event in your observability: what failed, what class it was, how much budget remains. When a run fails after exhausting its budget, the failure message should say so, and say what the last error was. "The run failed after 5 retries: the inventory service returned 429 three times" is a diagnosable failure. "Something went wrong, please try again" after two minutes of silent retrying is a trust incident. I wrote about that distinction in the first-failure post, and it applies here with interest: the retry loop is where silent failures are manufactured.

Fourth, and this is the one teams resist, distinguish model retries from tool retries. When a tool call fails because the model produced a bad argument, the fix is not to retry the tool. The fix is to give the model a better chance of producing a good argument: a tighter schema, a clearer description, an example in the prompt, a validation step before the call goes out. Retrying a bad tool call is treating a model error as a network error. It is the wrong medicine for the disease, and it is expensive medicine. If your traces show the same tool failing with argument errors more than once a day, you do not have a retry problem. You have a tool design problem. I wrote about that in the tool-design post, and the retry budget is where the bill for bad tool design arrives.

## The counterargument, honestly stated

There is a real case for generous retries, and it deserves a fair hearing. Some failures are genuinely transient and genuinely invisible to the caller: a load balancer drops a connection, a DNS lookup hiccups, a deploy rolls through the fleet mid-request. For those, a retry is pure win, and the cost of not retrying is a user-visible failure that never needed to happen. Nobody wants to tell a user the run failed because of a one-second network blip.

The answer is not to stop retrying. The answer is to retry narrowly, on the failure classes where the next attempt has a real chance of succeeding, and to stop retrying the moment the evidence says the failure is sticky. The discriminator is information: does the error tell you the world might be different next time? A timeout says maybe. A 400 says no. A repeated identical failure says no, louder each time. A retry policy that cannot tell the difference is not resilient, it is indiscriminate, and indiscriminate systems fail indiscriminately.

There is also an organizational argument worth naming. Generous retries feel safe to the team that ships them. Nobody gets paged for a retry. Nobody writes a postmortem that says "we retried too little." The failure mode of under-retrying is loud and immediate, a user-visible error, while the failure mode of over-retrying is quiet and diffuse, a cost line that creeps up and a latency distribution that slowly fattens. Teams optimize for the failure they can see. That is human, and it is also how you end up spending real money to hide real bugs.

## The rule I actually use

Here is the rule, stripped to one paragraph. Budget retries at the run level, not just the step level. Classify errors before you retry them, and never retry an error class you have not explicitly approved. Cap the budget small, five per run is a good starting point, and make exhaustion a loud, diagnosable failure instead of a silent one. And treat repeated identical failures as evidence, not bad luck: two identical failures in a row is a signal to stop and surface the error, not to try a third time and hope.

The sharp version: your agent does not need more retries. It needs a retry policy that knows when to quit. Resilience is not the number of times you are willing to try again. It is the speed with which you can tell a transient fault from a real one, and the discipline to stop spending on the real ones.

What is the worst retry loop you have seen in a production trace? I am curious how many of them were the same tool, the same bad argument, and the same error message, three or more times in a row.
