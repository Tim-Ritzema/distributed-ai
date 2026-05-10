# Event System

## Purpose

Define the event envelope every event in the system carries, and the concerns the broker must address. Broker-agnostic — see [ADR-0002](../05-decisions/0002-event-broker.md) for the technology decision.

## The envelope

```
event_id                       UUID          required, dedup/audit/replay key
schema_version                 string        required, forward-compat
type                           string        required, e.g. "perception.face.seen"
source_type                    enum          required: device | brain | scheduler | workflow | agent | system
source_id                      string        required, identifier within source_type
                                             (device_id, workflow_run_id, agent_session_id, ...)
actor_principal_id             string?       family-member principal who performed THIS event's action
                                             (null for non-human originators)
triggered_by_principal_id      string?       family-member principal who initiated the chain
                                             that led to this event, even if a workflow/agent/scheduler
                                             performs the actual step
subject_principal_ids          [string]      principals the event is ABOUT (may be empty)
owner_principal_id             string        whose data this event belongs to — family member OR `household`
room_id                        string?       physical context
payload                        object        type-specific
privacy_tier                   enum          private-personal | family-shared | room-safe | public-ambient
publish_capability_required    [Capability]  capabilities a producer must hold to publish; AND-semantics
subscribe_capability_required  [Capability]  capabilities a consumer must hold to subscribe; AND-semantics
audience                       [string]?     intended principals/devices for presentation events
timestamp                      ISO-8601      required
correlation_id                 string?       groups related events
causation_id                   string?       event_id that caused this one
idempotency_key                string?       producer-supplied dedupe key
```

`Capability` is a structured value: `{name: string, scope?: object}`. Equivalent DSL form used in docs and logs: `"memory.read.private-personal[owner=tim]"`. **Scope keys are lowercase stable IDs** (`owner=tim`, `room=kitchen`, `device=kitchen-pi-01`) — never display names. Multiple required capabilities AND together. The broker enforces `publish_capability_required` against the producer at publish time and `subscribe_capability_required` against each consumer at subscribe time. These requirements are typically derived from the topic schema rather than chosen per-event; they appear in the envelope for audit clarity and replay correctness.

## Source fields

`source_type` distinguishes physical devices from internal originators:

- `source_type=device` — physical devices (Pi, mobile, static install, laptop client).
- `source_type=brain` — events emitted by the control plane / agent runtime itself.
- `source_type=scheduler` — cron / timer-driven events.
- `source_type=workflow` — events emitted from inside a workflow run.
- `source_type=agent` — events from an autonomous reasoning loop (e.g., a heartbeat-driven task run).
- `source_type=system` — infrastructure events (deploy, broker reconnect, capability-grant changes).

`actor_principal_id` is `null` for any non-`actor` source (device, scheduler, workflow, agent, system, or brain-internal). System-ness is conveyed by source fields, not by a fake "system" principal.

## Actor / Triggered-by / Subject / Owner / Observer

A load-bearing distinction:

- **Actor** — the family-member principal who **performed the specific action** that produced this event. Null for non-human originators (device emitting an observation, workflow performing a step, scheduler firing a tick, agent loop iterating).
- **Triggered by** — the family-member principal who **initiated the chain** that led to this event, even if a non-human entity performed the step. A workflow Tim queued has `actor=null, triggered_by=tim`. A nightly scheduled reflection has `actor=null, triggered_by=null` (the chain is autonomous). Use this to filter "events I started" without conflating "events I performed."
- **Subject** — who the event is about. May or may not be the actor; may be empty.
- **Owner** — whose data the event becomes once stored. May be a family member or `household`.
- **Observer** — the device or process that witnessed/produced it (`source_type` + `source_id`).

Worked examples (used also by [data-model.md](data-model.md) and [example-flows.md](example-flows.md)):

- **Known face seen.** Kitchen Pi publishes `perception.face.seen`. `source_type=device`, `source_id=kitchen-pi-01`, `subject=[tim]`, `owner=tim`, `actor=null`, `triggered_by=null`, `room=kitchen`, `privacy_tier=room-safe`, `publish_capability_required=[perception.publish[device=kitchen-pi-01]]`, `subscribe_capability_required=[presence.read[room=kitchen]]`. The underlying camera frame, if retained, has `privacy_tier=private-personal` and a stricter capability gate, on a separate topic.
- **Unknown face seen.** Same Pi publishes `perception.face.unknown`. `subject=[]`, `owner=household`, `actor=null`, `triggered_by=null`, `privacy_tier=family-shared`, `subscribe_capability_required=[security.read.unknown-faces]`.
- **Workflow progress.** A workflow run emits `job.progress`. `source_type=workflow`, `source_id=<run_id>`, `actor=null` (the workflow performs the step, not Tim), `triggered_by=tim` (Tim queued the job), `owner=tim`, `audience=[devices owned by tim]`.
- **Scheduler tick.** Nightly reflection fires `agent.reflection.start`. `source_type=scheduler`, `source_id=nightly-reflection`, `actor=null`, `triggered_by=null`, `owner=household`.
- **Tim sends a chat message.** `source_type=device`, `source_id=tims-iphone`, `actor=tim` (Tim performed the action himself), `triggered_by=tim`, `subject=[tim]`, `owner=tim`.

## Broker concerns

The broker chosen in [ADR-0002](../05-decisions/0002-event-broker.md) must address all of these:

- **Schema validation on publish.** Reject events that don't match the registered schema for their `type`.
- **Idempotency** via `event_id` and producer-supplied `idempotency_key`. Re-publishes don't double-deliver.
- **Replay** against the durable history plane. Consumers can rewind to a `correlation_id` or timestamp.
- **Per-topic retention windows.** Raw biometric topics retain for minutes; audit topics retain indefinitely.
- **Dead-letter queues.** Events that fail handler processing land in a DLQ with diagnostic context.
- **Ordering guarantees.** Per-key (e.g., per-room or per-correlation_id) ordering at minimum. Global ordering is not required.
- **Backpressure semantics.** Slow consumers do not block fast ones; over-backed-up consumers get dropped or paused with audit.
- **Authorization on both publish and subscribe.** `publish_capability_required` checked against the producer's capability set; `subscribe_capability_required` checked against each consumer's.
- **Consumer contracts.** Each topic documents what shape of payload to expect, what capability is required, and what guarantees the consumer can rely on.
- **Priority lanes** (high / medium / low) borrowed in concept from local-vida — high-priority topics get preferential dispatch.

## Design Invariants

- **No event without an envelope.** Even internal `source_type=brain` events fill in the full envelope; this is what makes audit and replay tractable.
- **Capabilities are checked at the broker, not just by handlers.** A handler that forgot to check is a defense-in-depth failure, not the only line of defense.
- **`source_type=system` events still carry `owner_principal_id`.** Default to `household` if no clearer owner exists.
- **The envelope is forward-compatible via `schema_version`.** Adding fields is fine; removing or renaming requires a version bump.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres holds events stored for durable history (specific layout TBD with broker decision).

## Open Questions

- 🟣 [ADR-0002](../05-decisions/0002-event-broker.md) — broker for realtime + durable planes, staged path proposed.
- Topic naming convention. Provisional: dot-separated lowercase tokens, no underscores. Typically `<domain>.<entity>.<verb>` (e.g., `perception.face.seen`, `work-item.task.assigned`), but `<domain>.<verb>` (e.g., `presence.changed`, `job.progress`) and `<domain>.<state>` (e.g., `job.succeeded`) are also valid where the entity is implicit. To be ratified after first implementation pass.
