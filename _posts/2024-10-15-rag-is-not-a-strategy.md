---
layout: post
title: "RAG Is Not a Strategy"
description: "Bolting a vector search onto a model is not a retrieval system. What real retrieval engineering looks like."
date: 2024-10-15
tags: [rag, retrieval, craft]
---

Ask a team how their retrieval works and you will hear some version of: we chunk the docs, embed them, store them in a vector database, and pull the top five chunks at query time. That is not a retrieval strategy. That is a dependency with extra steps.

A vector database is plumbing. Retrieval is the discipline of getting the right information in front of the model at the right time, and it is where most RAG systems quietly fail. The model gets blamed for hallucinating, but half the time it was simply never given the facts. You cannot generate what you were never shown.

## Why naive top-k fails

Cosine similarity between embeddings measures something like "these texts are about similar things." That is not the same as "this text answers the question." A chunk that discusses the topic in general terms will outrank the chunk with the exact answer if the general chunk shares more vocabulary with the query. Semantic similarity is a proxy for relevance, and proxies leak.

Then there is the chunk boundary problem. Fixed-size chunking with overlap is the default because it is easy, not because it is good. It splits tables in half, separates a definition from the term it defines, and buries the crucial sentence at the tail of a chunk whose first 400 tokens are boilerplate. The retriever then has to rank a chunk whose embedding is dominated by irrelevant text. Overlap papers over this; it does not fix it.

And top-k itself is a blunt instrument. The right answer might be in chunk 12, but you only fetched 5. Or the answer needs two chunks that individually score low but jointly complete the picture. Naive top-k assumes relevance is concentrated and independent. Real knowledge is neither.

## Chunk for the unit you need

Chunking should follow the structure of your content, not an arbitrary token count. If your corpus is documentation, chunk by section. If it is tickets, chunk by ticket. If it is code, chunk by function. The retrieval unit should be the smallest unit that is still self-contained enough to be useful on its own.

Each chunk should also carry metadata: source, date, section path, document title. The model needs to know where a fact came from to weigh it, and your future self needs it for debugging. A chunk without provenance is a rumor.

A useful test: show a random chunk to a colleague with no context and ask if it is understandable on its own. If not, your chunks are fragments, and fragments retrieve badly.

## Dense is not enough: go hybrid

Dense embeddings are bad at exact matches. Ask about a specific SKU, an error code, a person's name, a part number, and the embedding will happily return chunks about similar-sounding but wrong entities. This is not a minor edge case. In enterprise corpora, the exact term is often the entire query.

BM25, the old lexical workhorse, is bad at paraphrase but excellent at exact terms. The answer is not dense versus sparse, it is both. Run them in parallel and fuse the rankings, with reciprocal rank fusion or a weighted combination. The two methods fail in different ways, which is exactly what you want from an ensemble.

Tune the weights on real queries, not on intuition. The right blend depends on your corpus: SKU-heavy catalogs lean lexical, conceptual documentation leans dense. There is no universal ratio, which is why this is engineering and not configuration.

## Re-rank: cheap recall, expensive precision

The pattern that actually works at scale is two-stage. Stage one is cheap and broad: hybrid retrieval pulls the top 50 or 100 candidates. Stage two is expensive and precise: a cross-encoder reranker scores each candidate against the query directly, reading query and document together instead of comparing precomputed vectors.

Cross-encoders are slower, which is why you only run them on the shortlist. But the quality jump is real, because the reranker does what embeddings cannot: it actually reads. It notices that the chunk mentions the term but in the wrong context, or that the answer is present but hedged, or that two chunks together form the complete answer.

If you do one thing to improve a naive RAG system, add reranking. It is the highest-leverage change I know in retrieval.

## Rewrite the query before you search it

User queries are bad retrieval queries. They are short, ambiguous, full of pronouns, and missing the vocabulary the documents use. Searching with the raw user query is like asking a librarian a question phrased as a riddle.

Query rewriting fixes the mismatch: expand the query with likely terms, resolve pronouns from conversation history, and when the request is complex, decompose it into sub-queries and retrieve for each. A cheap model call that turns "how do I fix the thing from yesterday" into three concrete search queries pays for itself many times over in retrieval quality.

This is also where conversation history belongs: not dumped raw into the search, but distilled into what the current question actually needs.

## Measure retrieval separately from generation

Here is the diagnostic most teams never run: evaluate retrieval on its own. Build a small set of queries with known relevant documents, and measure recall at k and mean reciprocal rank. If retrieval recall is 60 percent, your generation quality is capped at 60 percent no matter how good the model is, because four times in ten the model never sees the answer.

Separating the two measurements tells you where to invest. Bad retrieval scores mean fix chunking, hybrid weights, reranking. Good retrieval with bad answers means the problem is in generation: prompt, context assembly, or the model itself. Without the split, you are tuning blind, usually by fiddling with the prompt while the retriever quietly drops half the facts.

A concrete habit: log the retrieved chunks alongside every answer, and when an answer is wrong, check first whether the right chunk was even retrieved. In my experience, more than half of RAG failures are retrieval failures wearing a generation costume.

## The retrieval-generation contract

One more thing teams get wrong: they treat retrieval and generation as independent stages, when they need a contract between them. Retrieval will never be perfect. The generator must be designed for imperfect retrieval, which means three behaviors worth building deliberately.

First, cite. When the model uses a retrieved fact, it should say which chunk it came from. Citations do two jobs: they let users verify, and they let you trace a wrong answer back to the chunk that caused it. A RAG system without citations is undebuggable by its own users.

Second, express uncertainty about coverage. If the retrieved chunks do not contain the answer, the model should say so rather than confabulating. This has to be trained or prompted explicitly, because the default behavior of a helpful model is to produce an answer-shaped response from whatever it has. "The retrieved documents do not cover this" is a feature, not a failure mode.

Third, never let generation paper over retrieval gaps silently. The most dangerous RAG output is the confident, fluent, completely unsupported answer. It looks like the system worked. It is worse than an explicit failure, because nobody investigates a success.

## The real thesis

RAG is not "embeddings plus a vector database." It is retrieval engineering: chunking with intent, hybrid search tuned to the corpus, reranking for precision, query rewriting for the mismatch between how users ask and how documents answer, and measurement that separates retrieval quality from generation quality.

The vector database is the least interesting part of the system. It is the shelf. What matters is the librarian: what gets shelved, how it is indexed, and how good the search is. Teams that treat RAG as a strategy have a shelf. Teams that do retrieval engineering have answers.

Where is your retrieval actually failing: the chunks, the search, or the measurement you never built?
