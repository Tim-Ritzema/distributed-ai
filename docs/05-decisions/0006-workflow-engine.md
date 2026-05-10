# ADR-0006: Workflow engine

**Status:** 🟣 proposed (Prefect leading; not yet accepted)

## Context

The system needs a workflow engine for multi-step Python AI/ML jobs ([02-domains/background-processing.md](../02-domains/background-processing.md)) — vision, transcription, embeddings, research, scheduled analysis, coding agents. The engine is **not the event backbone**; it's the orchestrator for long-running, retry-aware, observable jobs.

## Options

### Option A — Prefect (lead candidate)

- **Pros:**
  - Python-native. Same language as the AI/ML workers.
  - Mature retries, scheduling, parameterized runs, branching.
  - Self-hosted server; runs comfortably alongside the Brain.
  - Good visibility (UI, logs, run history).
  - Pattern proven in local-vida.
  - Easy to define workflows close to the worker code.
- **Cons:**
  - Self-hosted Prefect Server has operational footprint.
  - Long-running workflows (hours+) work but want care around durability.
  - Async story is workable but not as natural as in some alternatives.

### Option B — Oban (Elixir-side)

Since [ADR-0001](0001-control-plane-language.md) accepted hybrid Elixir+Python, Oban — a Postgres-backed job queue with retry/scheduling — is a real candidate for simple Elixir-side background jobs.

- **Pros:**
  - Lives in Postgres; transactional with the rest of the data.
  - Excellent for simple background work in an Elixir app.
  - No additional service to operate.
- **Cons:**
  - Designed for jobs, not multi-step branching workflows. Complex flows get awkward.
  - Workflow logic in Elixir; AI/ML work is in Python — round-tripping adds latency.
  - Not the right tool for genuine workflow orchestration.

### Option C — Temporal

Heavyweight but very durable workflow engine. Strong story for long-running, fault-tolerant flows.

- **Pros:**
  - Built specifically for durable long-running workflows.
  - Excellent retry, versioning, and replay semantics.
  - Polyglot SDK (Python, Go, Java, etc.).
- **Cons:**
  - Significant operational overhead (Temporal Server is multi-process).
  - Overkill for household-scale workloads.
  - Steeper learning curve.

## Decision

**Proposed: Prefect** for Python AI workflows. Recommendation made; awaiting confirmation.

Rationale:

- AI workers are Python; Prefect is Python; matched.
- Prefect's local self-hosted story is solid for our scale.
- We need real workflow orchestration (multi-step, retries, branching, progress events), not just a job queue.
- Local-vida proved the pattern works for similar workloads.

**Oban** is a candidate for **simple Elixir-side background jobs** since [ADR-0001](0001-control-plane-language.md) accepted hybrid Elixir+Python. For example, the Brain's maintenance loop sweeps could be Oban jobs while AI work goes to Prefect. This is not a competition between Oban and Prefect; they serve different layers.

**Temporal** is parked as a future option only. Trigger to revisit: Prefect's durability for hours-to-days workflows proves insufficient, or a need for cross-team workflow versioning emerges (unlikely at family scale).

## Consequences

If Prefect accepted:

- Prefect Server runs as part of the deployment.
- Workflows defined as Python flows alongside the worker code they call.
- Job state (queued → running → progressing → terminal) lives in Prefect's DB; durable results land in Postgres ([ADR-0007](0007-persistent-state-postgres.md)) referenced by `job_id`.
- Progress events bridge from Prefect into the realtime plane via the Brain.

## References

- [02-domains/background-processing.md](../02-domains/background-processing.md) — workflow runner role.
- [01-architecture/system-planes.md](../01-architecture/system-planes.md) — workflow orchestration plane.
- [ADR-0001](0001-control-plane-language.md) — accepted hybrid Elixir+Python; makes Oban a real candidate for the Elixir side.
