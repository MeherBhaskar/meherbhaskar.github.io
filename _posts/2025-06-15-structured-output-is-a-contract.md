---
layout: post
title: "Structured Output Is a Contract"
description: "Schemas are the boundary between the probabilistic and the deterministic parts of your system. Treat them like it."
date: 2025-06-15
tags: [craft, agents]
---

Every agent system is two systems glued together: a probabilistic part that reasons in prose, and a deterministic part that acts on the results. The glue is structured output. The schema is the contract between what the model dreams up and what the code executes. Teams that treat schemas casually get systems that fail mysteriously. Teams that treat them as contracts get systems they can reason about.

## The boundary that matters

Think about what happens without structured output. The model writes a paragraph, some code parses the paragraph with a regex or a prayer, and the extracted fields flow into tools, databases, and downstream agents. Every parse is a gamble. The model rephrases, the regex misses, the field silently becomes null, and three steps later something acts on the null as if it were real.

Structured output converts this gamble into a commitment. When the model must produce JSON matching a schema, the output is machine-checkable. It either validates or it does not. There is no "probably parsed correctly." That binary property is the whole game: it moves a class of failures from silent corruption to loud, catchable errors.

This is why the schema belongs at the center of your design, not as an afterthought. Define what each step must produce before you worry about how the model produces it. The schema is the specification of the handoff, and everything downstream depends on it holding.

## Define once, validate everywhere

The most common schema failure I see is not a bad schema, it is a schema that exists in exactly one place: the prompt. The prompt says "respond in JSON with fields X, Y, Z," and nothing else in the system knows about X, Y, and Z. The producer and the consumer share no definition, so they drift.

Define schemas once, in code, and share the definition between the producer and the consumer. The prompt can describe the schema, but the code owns it. Then validate at every boundary: when the model output arrives, before it enters a tool, before it crosses to another agent, before it is stored.

```python
from pydantic import BaseModel, ValidationError

class Extraction(BaseModel):
    entity: str
    confidence: float
    evidence: list[str]

def run_step(raw_output: str) -> Extraction:
    try:
        return Extraction.model_validate_json(raw_output)
    except ValidationError as e:
        return repair(raw_output, e)
```

Validation is error detection, and error detection is what turns silent corruption into a recoverable event. A validation failure is good news: it means you caught the problem at the boundary instead of discovering it three steps later as a bizarre downstream decision.

## Build the repair loop

Validation without repair is just a fancier crash. When output fails validation, do not give up and do not silently coerce. Repair it.

The repair loop is simple and effective: take the invalid output, the schema, and the validation errors, and ask the model to fix specifically what failed. "Your output failed validation: field 'confidence' must be a number between 0 and 1, got 'high'. Here is the schema. Produce corrected JSON."

```python
def repair(raw: str, err: ValidationError, retries: int = 2) -> Extraction:
    for _ in range(retries):
        fixed = model.complete(REPAIR_PROMPT.format(
            schema=Extraction.model_json_schema(),
            output=raw,
            errors=err.errors(),
        ))
        try:
            return Extraction.model_validate_json(fixed)
        except ValidationError as e:
            raw, err = fixed, e
    raise UnrecoverableOutput(err)
```

Two properties make this work. First, the errors are specific: the model is not guessing what went wrong, it is told. Targeted feedback beats "try again" by a wide margin. Second, the retries are bounded: if the model cannot produce valid output after a couple of attempts, something is structurally wrong, and failing loudly beats looping forever. Cap the retries, log the failures, alert on the rate.

Track your schema violation rate as a first-class metric. A rising rate means the model, the prompt, or the world changed. It is an early warning system for drift, and it is free if you are already validating.

## When to constrain, when to roam

Not everything should be schema-bound. Constraining the model too early kills the reasoning you wanted the model for. The art is in placing the boundary correctly.

Let the model roam in prose where the value is in the thinking: analysis, planning, weighing options. Constrain it to schemas where the value is in the acting: tool arguments, handoffs between agents, anything that enters deterministic code. A good rule: the model's internal monologue can be free text, but anything that crosses a boundary must be a contract.

There is a middle ground worth knowing: constrained decoding, where the schema is enforced during generation rather than validated after. It eliminates an entire class of violations by making invalid output unrepresentable. Use it where your stack supports it, especially for tool arguments. Validation-after is the fallback, not the ideal.

## Design schemas the model can fill

A schema is also a communication to the model, and models fill well-designed schemas more reliably than bad ones. A few rules from the trenches:

**Name fields like you mean them.** `x1`, `temp2`, `output_final_v2` are hostile. `entity`, `confidence`, `evidence` tell the model what belongs there. The model is pattern-matching on your field names against everything it has seen; clear names activate the right patterns.

**Describe every field.** A one-line description per field, "confidence: the model's estimated probability that the entity is correct, 0 to 1," removes entire categories of misinterpretation. This costs a few tokens in the prompt and saves many more in repair loops.

**Show one example.** A single valid example object is worth paragraphs of description. Models are excellent at continuing patterns and mediocre at following abstract specifications. Give the pattern.

**Prefer flat over nested.** Deeply nested schemas multiply the ways output can go wrong: every level is another chance to misplace a bracket or misunderstand the structure. Flatten where you can. If you need nesting, keep it shallow and make each level's purpose obvious.

**Constrain enums tightly.** Where the valid values are known, enumerate them. A field that must be one of `["low", "medium", "high"]` will not come back as "somewhat high" if the schema says so and validation enforces it. Every open string field is a small act of faith.

These are small disciplines, and they compound. A well-designed schema, described clearly, with an example, validated at the boundary, with a repair loop behind it, fails rarely and loudly. A sloppy schema fails often and silently. The difference shows up in your incident queue.

## Version your schemas

Schemas change. A field gets added, a type gets widened, a required field becomes optional. Every change is a potential break for every consumer, including the model, which learned the old shape from its prompt and examples.

Version them. Keep old versions parseable during transitions. When you change a schema, update the prompt, the examples, the validators, and the consumers together, and run the eval set before and after. A schema change is a migration, and migrations done casually are how production breaks on a Tuesday afternoon.

The contract metaphor holds all the way down: schemas are APIs between the probabilistic and deterministic parts of your system. Version them like APIs, test them like APIs, and respect them like APIs. The teams that do have systems whose failures are loud, local, and fixable. The teams that do not have mysteries.

Where is the weakest contract in your system right now?
