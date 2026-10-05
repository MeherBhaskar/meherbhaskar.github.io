---
layout: post
title: "Your Chunking Strategy Is Your Retrieval Strategy"
description: "Chunking decisions determine what retrieval can ever find. Most teams chunk by token count and hope."
date: 2025-11-17
tags: [rag, retrieval, craft]
---

Ask a team how they chunk documents for retrieval and the answer is usually a number: 512 tokens, maybe 1024, with some overlap. Ask why that number and you get a shrug. The chunking was decided once, early, by token count, and everything downstream, the embeddings, the ranking, the generation, has been compensating for that decision ever since.

Here is the uncomfortable truth: the chunk is the unit of retrieval. Your system can never retrieve half a chunk or combine fragments across chunks. Every chunking decision, boundaries, size, overlap, metadata, sets an upper bound on what retrieval can ever find. Chunking is not preprocessing. It is the retrieval strategy, wearing a preprocessing costume.

## What a chunk boundary destroys

A fixed-size chunker slices text every N tokens with no regard for meaning. A paragraph gets cut mid-sentence. A table gets split across two chunks. A section header ends up orphaned at the bottom of one chunk while its content starts the next. Each of these is a small act of destruction, and the embedding model faithfully embeds the wreckage.

The damage shows up as specific, recognizable retrieval failures. A query about a procedure retrieves the chunk containing steps 4 through 7 but not the chunk with steps 1 through 3, because the boundary fell between them. A query about a table's conclusion retrieves the numbers without the header row that explains what the columns mean. The retriever did its job perfectly. It returned the most similar chunk. The chunk was broken before similarity was ever computed.

Semantic chunking, splitting on document structure, headings, paragraphs, tables, lists, fixes the grossest damage. It is more work: you need parsers that understand your document formats, and real-world documents are messier than the tutorials admit. But a chunk that respects a semantic boundary carries its meaning with it, and meaning is what the embedding actually encodes.

The principle: chunk boundaries should fall where meaning does not cross. If a human reading the document would say "this belongs together," it belongs in one chunk.

## Size is a trade-off, not a setting

Small chunks give precise retrieval: the returned text is tightly relevant, with little noise. But small chunks lose context, and the generator receives fragments it must stitch together, which is where hallucinations breed. Large chunks preserve context but dilute relevance: the embedding averages over more text, the signal drowns, and the generator gets a wall of mostly irrelevant text with the answer buried somewhere inside.

There is no correct size, only a correct size for your documents and queries. The way to find it is embarrassingly direct: build a set of real queries with known relevant passages, try several chunking configurations, and measure recall, what fraction of the relevant passages appear in the top-k retrieved chunks. Most teams tune the embedding model and the reranker exhaustively while leaving chunking at the default. They are optimizing the wrong layer.

One pattern deserves special mention because it dissolves the trade-off rather than navigating it: hierarchical chunking. Index small chunks for precise retrieval, but when a small chunk hits, return its parent, the section or page it came from, to the generator. Precision at retrieval time, context at generation time. It requires keeping the parent-child mapping, which is bookkeeping, not magic. The teams that do this consistently outperform the teams arguing about whether 512 or 1024 is the magic number.

## Overlap: useful, then harmful

Overlap exists for one reason: to protect against boundary damage. If the answer spans a chunk boundary, overlap means it also appears whole inside a neighboring chunk. A little overlap, 10 to 20 percent, is cheap insurance.

More overlap is not more insurance. Heavy overlap floods the index with near-duplicate chunks, which distorts ranking: the same content occupies multiple top-k slots, crowding out genuinely different relevant passages. It also bloats the index and slows everything down. And it papers over bad boundaries instead of fixing them. If you need 50 percent overlap for your system to work, your boundaries are wrong. Fix the boundaries.

## Metadata is decided at chunk time, forever

The most underrated chunking decision is what metadata to attach. Source document, section heading, page number, date, author, document type: all of this is trivially available when you chunk and nearly impossible to reconstruct later. Metadata enables the filters that make retrieval actually work in production: "only policies updated this year," "only the safety manual, not the marketing wiki," "prefer the newest version."

Every production retrieval failure I have debugged that was not a chunking problem was a filtering problem, and every filtering problem traced back to metadata that was never attached. Attach generously. You will not regret having the section heading. You will regret not having it, at 2am, when the CEO asks why the agent quoted the 2019 policy.

## Re-chunking: documents change, chunks must follow

Everything above assumes a static corpus. Production corpora are not static. Documents get updated, sections get rewritten, policies get superseded. And here is the trap: when a document changes, the chunks must change with it, or retrieval starts returning the old version alongside the new one, and the generator happily synthesizes contradictions.

Re-chunking is an underappreciated operations problem. The naive approach, re-chunk everything nightly, works at small scale and falls over as the corpus grows. The better approach is change-driven: track document versions, re-chunk only what changed, and tombstone the old chunks so they stop being retrieved. This requires your chunk store to know which chunks came from which document version, which is more metadata, attached at chunk time, paying off again.

There is a subtler issue: chunk identity. If a paragraph moves within a document, is it the same chunk or a new one? If your analytics, your eval labels, or your caches reference chunk IDs, the answer matters. Stable chunk identities across re-chunks, derived from content hashes of semantic units rather than positions, keep everything downstream coherent. This is the kind of boring infrastructure work that never gets blogged about and quietly determines whether your retrieval system is operable.

Version your chunks like you version your prompts. The corpus is a living thing. Treat it that way.

## Evaluate the chunking, not just the retrieval

Here is the practice that separates serious teams: evaluate chunking directly, as its own layer, instead of only evaluating end-to-end answer quality. Build a probe set of queries with known relevant passages. For each chunking configuration, measure recall at k and precision at k. Change one thing at a time: boundary strategy, size, overlap, metadata. Watch the numbers move.

This turns chunking from folklore into engineering. "We use 512-token chunks with 10 percent overlap" becomes "we use semantic boundaries at the section level with 15 percent overlap because it gave us the best recall at k=5 on our probe set, and hierarchical parents for generation." One of these is a shrug. The other is a decision.

Your chunking strategy is your retrieval strategy. Everything downstream is compensation for what the chunks contain and how they are cut. Get the chunks right and the rest gets easier. Get them wrong and no embedding model will save you.

When did you last change your chunking, and what did you measure?
