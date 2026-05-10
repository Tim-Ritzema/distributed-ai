# Example Flows

## Purpose

Three concrete end-to-end walkthroughs that exercise the architecture across multiple planes, components, and access checks. When something in the architecture is unclear, write a flow that touches it.

---

## Flow 1: Kitchen Pi sees Tim, static display decides whether to speak

**Actors:** Kitchen Pi (camera + display), Brain, presence state, static display app.

**Step by step:**

1. Camera on `kitchen-pi-01` detects a face. On-device model recognizes Tim with confidence 0.94.
2. Pi publishes `perception.face.seen` to the device-telemetry plane (likely MQTT, [ADR-0005](../05-decisions/0005-device-telemetry-protocol.md)):
   - `source_type=device`, `source_id=kitchen-pi-01`
   - `subject=[tim]`, `owner=tim`, `actor=null`, `triggered_by=null`
   - `room=kitchen`
   - `privacy_tier=room-safe`
   - `publish_capability_required=[perception.publish[device=kitchen-pi-01]]`
   - `subscribe_capability_required=[presence.read[room=kitchen]]`
3. The Brain ingests the event. Capability check on `publish` succeeds (the Pi has the grant from pairing). Schema validation passes.
4. Brain updates derived presence state in Postgres: `kitchen` is now occupied by `[tim]`.
5. Brain publishes a derived `presence.changed` event on the realtime plane. Subjects: `[tim]`. Owner: `tim` for the personal-presence aspect; a separate `room.occupancy.changed` event with owner `household` carries the room-level fact.
6. The static display app subscribed to `presence.changed[room=kitchen]` receives the event over WebSocket.
7. Static display checks its own capability set:
   - It has `presence.read[room=kitchen]` — OK to know Tim is there.
   - It does **not** have `memory.read.private-personal[owner=tim]` — cannot surface Tim's private memories aloud.
   - It has `greet.public-ambient` and `greet.room-safe` — may speak Tim's name only when group-aware degradation permits.
8. Group-aware check: presence shows only Tim in the room → display may use `room-safe` tier. If presence had shown more than one person, the display would drop to `public-ambient` and stay generic.
9. Display speaks: "Hey Tim, welcome home." It does **not** mention any health, school, or financial context, even if asked — that requires a personal client, not an ambient device.
10. The raw camera frame, if retained at all, lives on a separate topic with `privacy_tier=private-personal` and `subscribe_capability_required=[perception.read.raw[device=kitchen-pi-01]]`. Most clients cannot see it. Retention is short ([perception-and-presence.md](../02-domains/perception-and-presence.md)).

**What this exercises:** event envelope, source/actor/subject/owner distinction, privacy tiers, capability-gated subscribe, group-aware degradation, raw-vs-derived perception split.

---

## Flow 2: Tim assigns AI a work-item, workflow runs, progress streams to SvelteKit

**Actors:** Tim (on his laptop SvelteKit client), Brain, work-item store, workflow runner, SvelteKit client UI.

**Step by step:**

1. Tim opens the work-item view in his SvelteKit client. He types a new task: "Research best 3-bay sink for kitchen renovation. Budget $400. Cast iron preferred." Assigns it to the AI agent.
2. SvelteKit sends `POST /work-items` over HTTP with the task payload. The HTTP API checks Tim's session, validates the request, writes the WorkItem to Postgres with `assignee=agent`, `status=ready`, `owner=tim`. Returns 201.
3. The Brain's heartbeat (event loop / agent runtime) periodically scans for `assignee=agent, status=ready` items. It picks up Tim's task.
4. Brain spawns a workflow run (Prefect, [ADR-0006](../05-decisions/0006-workflow-engine.md)). The workflow gets a bounded toolset: WebSearch, WebFetch.
5. Workflow emits `job.started`:
   - `source_type=workflow`, `source_id=<run_id>`
   - `actor=null` (the workflow performs the step, not Tim)
   - `triggered_by=tim` (Tim queued the job)
   - `owner=tim`, `audience=[devices owned by tim]`
6. SvelteKit client subscribed to `job.*[triggered_by=tim]` over WebSocket receives the event. UI shows a spinner and "Researching kitchen sinks..."
7. Workflow runs through steps: search → fetch a few candidate pages → extract specs → compare → summarize. Each transition emits `job.progress` with `{step, percent, message}`. SvelteKit shows live updates.
8. Workflow finishes. Emits `job.succeeded` with a `result_ref` pointing to a freshly written `Memory` (owner: `tim`, tier: `family-shared` since kitchen choices affect the household, provenance linked to the workflow events).
9. Workflow also creates a follow-up WorkItem (a comment / suggestion) on the original task. Updates original task `status=done`.
10. SvelteKit client receives the terminal event, hides the spinner, shows the summary inline. Tim can review and either accept the suggestion or comment back.

**What this exercises:** HTTP for CRUD, WebSockets for live, work-item hierarchy, autonomous heartbeat / Jarvis pattern, workflow runner role, progress events on the realtime plane, durable result in Postgres, memory creation with provenance.

---

## Flow 3: Bennett's mobile client asks about Tim's private data, request is denied

**Actors:** Bennett (kid, on his iPhone), Brain, capability check, audit log.

**Step by step:**

1. Bennett asks his AI client: "What was the result of dad's doctor appointment?"
2. Mobile client sends an HTTP request to the chat endpoint with Bennett's session.
3. Brain's chat handler classifies the intent: "memory query, subject=tim, class=health."
4. Brain checks Bennett's capability set for what's needed: `memory.read.private-personal[owner=tim]` — specifically scoped to Tim's owner record, plus the sensitive `health` class.
5. Bennett's capability set does **not** contain it. Default rule: kids cannot read parents' or siblings' private data ([identity-and-access.md](../02-domains/identity-and-access.md)).
6. Capability check fails **before any retrieval**. The Brain does not load the memory, does not feed it to a model, does not send anything to the cloud. Defense-in-depth: even if the Brain forgot this check, the broker / DB query would deny.
7. Brain writes an AuditLog entry: `actor=bennett, subject=tim, action=memory.read, decision=denied, reason=capability-missing[memory.read.private-personal[owner=tim]], correlation_id=<chat-turn>`.
8. Brain returns a generic, non-leaky response to Bennett: "I can't share that. You might want to ask your dad directly."
9. Notably, the response does **not** confirm the existence of the memory. It does not say "yes, Tim has a doctor appointment, but I can't tell you" — that's a privacy leak. The denial message is the same whether or not such a memory exists.
10. (Future flow.) An admin (parent) can review denied audit entries and decide whether to grant a one-off capability or have a conversation with Bennett.

**What this exercises:** capability-based access control, kid/parent default rules, defense-in-depth (the deny is the first thing to happen), audit log requirement for cross-principal access, deny-without-leakage UX, the difference between owner and subject.

---

## Why these three

- Flow 1 stresses the event system, multi-plane handoffs, raw-vs-derived split, and ambient privacy.
- Flow 2 stresses HTTP/WebSocket separation, workflow orchestration, autonomous task execution, and progress visibility.
- Flow 3 stresses capability-based access control, audit, and privacy-preserving denial.

Together they touch every load-bearing concept in [00-orientation/principles.md](../00-orientation/principles.md).
