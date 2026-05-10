# ADR-0003: Vector store

**Status:** 🔵 open

## Context

Memories may be embedded for similarity search ([02-domains/memory-and-context.md](../02-domains/memory-and-context.md)). The system needs a vector store. Two options are realistic at our scale.

## Options

### Option A — pgvector (in Postgres)

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

**Open.** Decision criteria for closing:

- How big do we expect the vector index to get in the next two years? Estimate: low hundreds of thousands of vectors. Both options handle this comfortably.
- How important is single-transaction memory + embedding writes? (Probably important for consistency and the deletion-cascade story.)
- How operationally minimal do we want Phase 0 to be? (Very minimal favors pgvector.)

Provisional lean: pgvector for Phase 0, with the option to migrate to Qdrant if performance or features become limiting. The migration is real work but tractable: re-embed and re-index.

## Consequences

If pgvector:

- One service. Memory + embedding writes are transactional. Filtering by tier/owner is a regular SQL `WHERE`.
- `embedding_ref` in the data model is just a row reference.

If Qdrant:

- Two services. Need an outbox / dual-write story for memory + embedding consistency.
- Cross-store auth needs explicit design.
- Richer filtering features available.

## References

- [02-domains/memory-and-context.md](../02-domains/memory-and-context.md) — embedding access rules.
- [01-architecture/data-model.md](../01-architecture/data-model.md) — `embedding_ref` field.
- [ADR-0007](0007-persistent-state-postgres.md) — Postgres is the persistent state plane.
