# Background Processing

## Purpose

Define the role of the workflow runner — what it is, what it isn't, and how multi-step Python AI work flows through it. The workflow runner is **not the event backbone**; it consumes events and emits progress, but the realtime event plane is a separate concern (see [system-planes.md](../01-architecture/system-planes.md)).

## Role

The workflow runner is for **multi-step Python AI/ML work** with retries, scheduling, visibility, and durable state. Examples:

- Vision processing on stored images.
- Speech transcription.
- Embedding generation.
- Research jobs ("look up these 12 things, summarize, write a memory").
- Coding agents (autonomous code-writing tasks).
- Scheduled analysis jobs (daily summaries, weekly reports).

It is **not**:

- The realtime event broker.
- The system nervous system.
- Where every async task lives. Quick async work belongs in the Brain's event handlers, not in workflow runs.

[ADR-0006](../05-decisions/0006-workflow-engine.md) tracks the engine choice — Prefect leads.

## Worker pools

Different workloads need different hosts. Provisional pools:

- **GPU-eligible.** Vision, transcription, large-model inference. Runs on hardware with appropriate accelerators.
- **CPU-heavy.** Embedding generation, web research, batch text processing.
- **Light.** Quick data shuffling, admin tasks, periodic sweeps.

A workflow declares its required pool; the engine schedules it accordingly.

## Job lifecycle

```
queued → running → progressing → succeeded
                ↘             ↘ failed
                  canceled
```

Each transition emits an event on the realtime plane:

- `job.queued` — job created.
- `job.started` — picked up by a worker.
- `job.progress` — periodic, with `{job_id, step, percent, message}`.
- `job.paused` — waiting for a human approval.
- `job.resumed` — approval received, continuing.
- `job.succeeded` — terminal, with `result_ref` pointing to the durable result in Postgres.
- `job.failed` — terminal, with error details and partial-result ref if any.
- `job.canceled` — terminal.

All events carry the standard envelope ([event-system.md](../01-architecture/event-system.md)). `actor=null` for these events — the workflow performs each step, not a human. `triggered_by` is the FamilyMember who queued the job (or null for autonomous chains). `owner` is typically the same as `triggered_by`; falls back to `household` for autonomous jobs. `audience` is the set of devices owned by the triggering principal so live UIs can pick up progress.

## Progress events

Progress events are deliberately structured rather than free-form, so UIs don't have to parse log lines:

```
{
  "job_id": "<uuid>",
  "step": "fetch_candidate_pages",
  "step_index": 3,
  "step_total": 7,
  "percent": 42,
  "message": "Fetched 4 of 6 pages..."
}
```

A SvelteKit client subscribed to `job.progress[triggered_by=tim]` receives these and renders a progress bar without polling.

## Retries

Per-step retry policy with exponential backoff. Steps with side effects (writing memories, sending notifications, calling external APIs) require an `idempotency_key` so retries don't duplicate work.

A workflow's terminal failure is reached only after retries are exhausted; an in-progress step that's retrying still emits `job.progress` so observers can see what's happening.

## Human-in-the-loop

Some workflows pause for human approval before taking impactful actions. Examples:

- Sending an email on a family member's behalf.
- Committing code to a repo.
- Making a purchase.
- Sharing a memory across tiers (loosening — see [memory-and-context.md](memory-and-context.md)).

Mechanism:

1. Workflow reaches a `await_approval` step. Emits `job.paused` with the request and a `correlation_id`.
2. A trusted client (admin's phone or a personal client of the owner) receives the event over WebSocket and renders an approval prompt.
3. User approves or denies via HTTP `POST /jobs/{job_id}/approvals` (CRUD action, not WebSocket — approvals are durable, idempotent decisions).
4. Workflow receives the approval (signed and audit-logged), emits `job.resumed`, and continues.
5. Denial transitions the job to `failed` with reason `denied-by-<principal>`.

Approvals time out (default: 24 hours) and require re-prompting if exceeded.

## Results flow

When a workflow completes:

1. Terminal event (`job.succeeded` / `job.failed` / `job.canceled`) published on the realtime plane.
2. Durable result written to Postgres referenced by `job_id`. Could be a Memory, a WorkItem update, an audit-log entry, or a structured `Job.result` blob.
3. Subscribed clients render the result inline (e.g., the SvelteKit client showing the research summary in Flow 2).
4. Memory creation includes provenance back to the originating workflow events ([memory-and-context.md](memory-and-context.md)).

## Engine choices

| Engine | Status | Use case |
|---|---|---|
| Prefect | 🟣 Leading | Python-native, good local story, mature retries/scheduling/visibility. The default day-one. |
| Oban | candidate (Elixir-side) | Relevant since [ADR-0001](../05-decisions/0001-control-plane-language.md) accepted hybrid Elixir+Python; Oban fits simple Elixir-side jobs (maintenance loop sweeps, schedule ticks). Complementary to Prefect for AI work, not in competition. |
| Temporal | future-only | If Prefect's durability for long-running workflows proves insufficient. |

See [ADR-0006](../05-decisions/0006-workflow-engine.md).

## Design Invariants

- **Workflow runner is not the event bus.** Workflows publish to the bus and consume from it; they do not replace it.
- **Side-effecting steps require idempotency keys.** Retries are guaranteed to happen.
- **Progress is observable.** A long-running workflow with no `job.progress` events for too long is a bug, not normal.
- **Human-in-the-loop approvals are durable.** Approvals are HTTP CRUD, not WebSocket messages — they survive client disconnects.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — job state and results in Postgres.

## Open Questions

- 🟣 [ADR-0006](../05-decisions/0006-workflow-engine.md) — Prefect leading.
- Worker-pool composition. Initial deployment may collapse all pools onto one host; split when contention shows.
- Long-running workflows (hours+). Prefect handles this; verify durability under restarts during Phase 1.
