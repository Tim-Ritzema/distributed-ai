# ADR-0003: Vector store

**Status:** 🟢 accepted

## Context

Memories may be embedded for similarity search ([02-domains/memory-and-context.md](../02-domains/memory-and-context.md)). The system needs a vector store.

[ADR-0007](0007-persistent-state-postgres.md) already accepts Postgres as the durable source of truth. The initial database deployment now runs on `mac-mini-1`, which makes a Postgres extension the lowest-operational-cost path for Phase 0.

Initial runtime as of this decision:

- PostgreSQL `18.4 (Homebrew)` via Homebrew `postgresql@18`.
- pgvector `0.8.2`.

## Options

### Option A — pgvector (in Postgres, accepted)

- **Pros:**
  - One fewer service to operate.
  - Embeddings live next to the memory rows they describe — single transaction, no consistency dance.
  - Postgres is already the source of truth ([ADR-0007](0007-persistent-state-postgres.md)); embedding access goes through the same auth model.
  - Familiar query language; can join with relational tables for filtering.
  - Solid for our scale (thousands to low millions of vectors).
- **Cons:**
  - At very large scale or with exotic indexing needs, dedicated vector stores outperform.
  - Index tuning requires Postgres expertise.

### Option B — Qdrant (separate service)

- **Pros:**
  - Purpose-built; rich filtering, payload indexing, multiple distance metrics.
  - Collection-level configuration (different memory categories can have different settings).
  - Pattern proven in local-vida.
  - Scales further if needed.
- **Cons:**
  - Another service to operate, monitor, back up.
  - Cross-store consistency: embeddings in Qdrant, memory rows in Postgres — risk of drift on failure.
  - Auth integration needs explicit work to align with the capability model.

## Decision

**Use pgvector in Postgres for memory embeddings.**

This keeps memory rows and their embeddings in the same transactional store. Qdrant remains a valid future escape hatch if scale, indexing features, or performance requirements outgrow pgvector, but it is not a Phase 0 dependency.

## Consequences

- One service for relational state and vector search. Memory + embedding writes are transactional.
- Filtering by owner, privacy tier, category, and capability-derived predicates stays in SQL.
- `embedding_ref` in the data model is a Postgres row reference, not an external collection id.
- Backups and restore procedures for Postgres cover embeddings too.
- Index tuning now belongs to the Postgres operations story.
- If pgvector becomes limiting, a later ADR can supersede this one and define the Qdrant migration. The migration shape is tractable: re-embed or export existing embeddings, rebuild indexes, and switch `embedding_ref` semantics.

## References

- [02-domains/memory-and-context.md](../02-domains/memory-and-context.md) — embedding access rules.
- [01-architecture/data-model.md](../01-architecture/data-model.md) — `embedding_ref` field.
- [ADR-0007](0007-persistent-state-postgres.md) — Postgres is the persistent state plane.
