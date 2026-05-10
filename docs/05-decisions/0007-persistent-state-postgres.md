# ADR-0007: Persistent state — Postgres

**Status:** 🟢 accepted

## Context

Every system needs a source of truth for durable application state — family principals, devices, capability grants, work items, memories, audit logs, job results. The choice has cascading effects on every other layer (data model assumptions, transactional guarantees, available extensions).

For a self-hosted, family-scale system, the candidates were ordinary: Postgres, SQLite, MariaDB/MySQL, a document store. Postgres is the obvious choice and accepting it explicitly avoids drift.

## Options

### Postgres (accepted)

- **Pros:**
  - Mature, stable, well-understood operationally.
  - JSONB for flexible payloads where structure isn't fully fixed (event payloads, capability scopes).
  - LISTEN/NOTIFY for lightweight pub/sub (potentially the durable plane in [ADR-0002](0002-event-broker.md)).
  - pgvector extension for embedding storage (potentially the vector store in [ADR-0003](0003-vector-store.md)).
  - Strong relational primitives for the principal / device / capability model.
  - Extensions (pg_audit, pg_partman, etc.) cover a lot of operational needs.
  - Well-supported by every backend language under consideration.
  - Backup/restore story is well-trodden.
- **Cons:**
  - Operational care required: tuning, vacuuming, backups. Standard for Postgres; not a real obstacle at our scale.
  - Some workloads (very high write throughput) can stress a single instance, but we're nowhere near those volumes.

### Alternatives considered briefly

- **SQLite** — Great for embedded, but the multi-process/multi-host story isn't right for a Brain that may scale across machines.
- **MariaDB/MySQL** — Capable but doesn't match Postgres on JSONB, extensions, or community momentum for this kind of workload.
- **Document stores (Mongo, etc.)** — Wrong fit; we have rich relational structure (principals, devices, capabilities, hierarchies).

## Decision

**Postgres is the source of truth for durable app state.**

This is the only accepted technology decision in the project as of writing. Every other broker/store/runner is either a cache, a derived index, an event log, or an orchestration concern — all of which can be reconstructed (slowly, but correctly) from Postgres + the durable event log feeding it.

## Consequences

- Data model docs ([01-architecture/data-model.md](../01-architecture/data-model.md)) may assume relational primitives (foreign keys, transactions, JSONB).
- Migrations live alongside the application code; deployment includes a migration step.
- pgvector becomes the natural default for [ADR-0003](0003-vector-store.md), though Qdrant remains a real option.
- LISTEN/NOTIFY + outbox is a viable approach for the durable event history plane in [ADR-0002](0002-event-broker.md).
- Postgres becomes the most operationally important service; backups and recovery procedures must be solid before Phase 1.
- All other data stores are subordinate. If something contradicts Postgres, Postgres wins.

## References

- [00-orientation/principles.md](../00-orientation/principles.md) — invariant #5 references this ADR.
- [01-architecture/data-model.md](../01-architecture/data-model.md) — entities living in Postgres.
- [ADR-0002](0002-event-broker.md) — durable event history may use Postgres outbox.
- [ADR-0003](0003-vector-store.md) — pgvector is the lean.
