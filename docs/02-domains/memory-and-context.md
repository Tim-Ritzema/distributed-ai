# Memory and Context

## Purpose

How the system stores facts about the family, with the privacy and ownership rules that survive long-term. Memory is the most sensitive long-lived data the system holds.

## Categories

A memory falls into one of these categories:

- **Per-user-private.** A fact owned by a single family member. Tier defaults to `private-personal`. Examples: "Tim has a doctor's appointment Tuesday", "Bennett is allergic to peanuts" (kid-private, but parent-readable).
- **Family-shared.** A fact about the household. Owned by `household`. Tier defaults to `family-shared`. Examples: "Family vacation planned for July", "Kitchen renovation budget is $50k".
- **Ambient observation.** Derived facts from perception. Owned by the subject (or `household` for unknown subjects). Tier defaults to `room-safe` for derived presence and `private-personal` for raw biometric. Short retention by default.
- **Agent-internal.** Scratch / working memory the agent uses for ongoing tasks. Owned by `household`, tier `family-shared`. Cleared after the task completes unless promoted.

## Provenance

Every memory records:

- `source_event_id` — the event that produced it (and through `causation_id`, the chain of events back to root).
- `source_type` + `source_id` — the observer that produced the originating event. `source_type` is one of `device`, `brain`, `scheduler`, `workflow`, `agent`, `system` (matching the event envelope). A memory derived from a workflow run has `source_type=workflow`, `source_id=<run_id>`; a memory captured by a Pi has `source_type=device`, `source_id=kitchen-pi-01`.
- `capability_used` — the capability under which the data was captured.
- `confidence` — how sure the system is.

A memory without provenance cannot be created. This makes deletion-cascades, cross-tier audits, and "where did the system learn this?" questions tractable.

## Privacy tier and how it changes

Privacy tier inherits from the producing event. After creation, tier may change — but with strict rules:

- **Sensitivity may be tightened automatically.** If sensitive content is detected (e.g., a memory that started as `family-shared` mentions a health condition), the system auto-promotes it to `private-personal`. This is silent; no approval needed.
- **Loosening access always requires explicit user approval and is audit-logged.** Moving a memory from `private-personal` to `family-shared` is never silent.

In other words: **tightening is silent; loosening is never silent.**

This direction matters. The default is to err toward more restrictive; mistakes that tighten are recoverable (the owner can grant a one-off read), while mistakes that loosen leak data.

## Retention

Tier-driven defaults, user-configurable per family member:

| Category | Default retention |
|---|---|
| Per-user-private — health/finances | indefinite, owner-controlled |
| Per-user-private — other | indefinite, owner-controlled |
| Family-shared | indefinite |
| Ambient observation — derived presence | 30 days |
| Ambient observation — raw biometric | minutes to hours |
| Agent-internal scratch | task lifetime + 7 days |

A maintenance loop (one of the brain's three loops, [system-overview.md](../01-architecture/system-overview.md)) sweeps expired memories on schedule and emits a `memory.expired` audit event for each.

## Deletion

Right-to-forget per family member. When a memory is deleted:

1. The memory record is hard-deleted.
2. The corresponding embedding is removed from the vector store ([ADR-0003](../05-decisions/0003-vector-store.md)).
3. Memories *derived* from it (e.g., a summary that included this memory) are flagged for review by the agent on its next maintenance pass — not auto-deleted, since the summary may stand on its own, but the provenance link breaks and the derived memory's confidence is downgraded.
4. Deletion is audit-logged: `actor`, `subject`, `memory_id`, `reason`.

A family member's right-to-forget covers their own owned memories. A kid cannot force-delete a parent's memory of them; that's a conversation, not an API call.

## Embeddings

Memories may have embeddings in a vector store ([ADR-0003](../05-decisions/0003-vector-store.md) — pgvector vs Qdrant is open). Rules:

- **Embeddings of `private-personal` memories never leave the network.** The embedding model runs locally. Cloud embedding APIs are forbidden for this tier.
- **Embeddings of `family-shared` memories may use cloud embeddings only with cloud-egress capability.** Otherwise local.
- **Embeddings inherit the same tier and access rules as the underlying memory.** A capability check that allows reading the memory also allows reading the embedding for similarity search; otherwise the embedding is filtered out of search results.

## Local/cloud boundaries

Cloud LLM calls receive only memories whose tier permits egress (per [ai-orchestration.md](../01-architecture/ai-orchestration.md)). The Brain assembles prompts and is responsible for enforcing this — the AI Router never reads memory tables directly.

When in doubt: don't include the memory in the cloud prompt, or include a redacted version.

## Cross-user queries

The default rules from [identity-and-access.md](identity-and-access.md):

- **Parent → kid** memory reads are permitted (logged).
- **Kid → parent** memory reads are blocked.
- **Sibling → sibling** reads are blocked.
- All crossings — allowed or denied — are audit-logged with actor, subject, memory_id (allowed) or memory class (denied).

The audit log is owned by `household` and retained indefinitely.

## Design Invariants

- **No memory without provenance.** Storage layer enforces.
- **Tightening is silent; loosening is never silent.** Loosening writes to the audit log and requires owner approval (or admin approval for kid-owned memories).
- **Tier travels with derived data.** If three `family-shared` memories aggregate into a summary, the summary is at most `family-shared`. The aggregate inherits the most restrictive tier of its inputs by default.
- **Embeddings respect tier.** A search that crosses a tier boundary returns nothing for the higher-tier results, with audit-logged denials at the search layer.
- **Cloud egress requires cloud-egress capability.** Memories never go to cloud LLMs without explicit per-class consent.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — memory records in Postgres.

## Open Questions

- 🔵 [ADR-0003](../05-decisions/0003-vector-store.md) — pgvector vs Qdrant. Affects embedding storage layout but not the access model.
- Sensitive-content detection. How does the system decide a memory should be auto-tightened to `private-personal`? Probably a classifier in the Brain on memory creation; tunable.
- Forgetting cascade depth. When Tim deletes a memory, do summaries that referenced it get rewritten on next pass, or just flagged? Probably flagged; rewriting requires new model calls.
- Long-term memory consolidation. After N years, do we summarize and archive raw memories? Out of scope for now.
