# Data Model

## Purpose

The entities the system reasons about, their relationships, and the role distinctions (actor / subject / owner / observer) that drive access decisions. Specific table layouts live with the implementation; this doc defines the conceptual model.

## Entities

### Principal (abstract)

One of: **FamilyMember**, **Household**, or **ServicePrincipal**. Identified by a lowercase stable ID.

Role constraints:

- **Owner principals** are restricted to FamilyMember or Household. ServicePrincipals never own data — anything an autonomous agent produces is owned by the principal who triggered it (a family member) or by the Household.
- **Actor principals** are restricted to FamilyMember (and only when a human truly performed the action). System / workflow / scheduler / agent / device originated events have `actor=null`.
- **Triggered-by principals** are restricted to FamilyMember (or null for autonomous chains).
- **Assignee principals** for work items may be FamilyMember or ServicePrincipal (e.g., `agent`).

### FamilyMember

A human principal: Tim, Laurie, Bennett, Drew, David, William.

- `id` — lowercase stable ID (`tim`, `laurie`, ...).
- `display_name` — used only in UIs.
- `role` — `parent` | `kid`.
- `created_at`, `updated_at`.

### Household

The singleton non-human principal that owns family-shared data, room-occupancy facts, and observations whose subject is unknown.

- `id` — `household`.
- `members` — derived; the set of FamilyMembers.

### ServicePrincipal

A non-human principal that can execute work, hold capabilities, and receive assignments — but **never populates `actor_principal_id`** (actor is FamilyMember-only) and **never owns data** (owners are FamilyMember or Household). When a ServicePrincipal performs a step, the originating event has `actor=null` and the source fields (`source_type=workflow`/`agent`/etc.) convey origin.

The canonical service principal today is `agent` — the AI itself. Other service principals may be added later (e.g., `prefect-scheduler` for autonomous workflow scheduling) when the need arises.

- `id` — lowercase stable ID (`agent`, ...).
- `display_name`.
- `kind` — `agent` | etc. (open-ended).
- `capability_set` — what the service is allowed to do.
- `created_at`.

ServicePrincipals are **not** assigned a `role` (`parent`/`kid`); those are FamilyMember-only.

### Device / Client

A registered hardware-or-software endpoint that connects to the system on behalf of a principal.

- `id` — opaque identifier.
- `kind` — `mobile` | `web-portal` | `static-install` | `pi` | `worker` | etc.
- `owning_principal_id` — typically a FamilyMember (a personal phone) or Household (a shared static install).
- `identity_pubkey` — long-lived; sessions are derived from it.
- `capability_set` — list of granted capabilities (see Capability below).
- `produces_source_type` — which `source_type` value its events carry.
- `paired_at`, `last_seen_at`, `revoked_at?`.

### Room / Location

A physical place that constrains presentation.

- `id` — e.g., `kitchen`, `living-room`, `garage`.
- `display_name`.

### Capability

A structured grant: `{name, scope?}`, with lowercase stable IDs in scope keys. Granted to a (Device, Principal) pair. Governs both API actions and event topic publish/subscribe.

- `name` — e.g., `memory.read.private-personal`, `perception.publish`, `presence.read`.
- `scope` — optional `{key: id}` dict, e.g., `{owner: "tim"}` or `{room: "kitchen"}`.
- `granted_at`, `revoked_at?`, `granted_by_principal_id`.

DSL form used in logs and docs: `name[key=value]`.

### Event

Matches the envelope in [event-system.md](event-system.md). Key fields:

- `event_id` — UUID, unique.
- `type`, `schema_version`.
- `source_type` + `source_id` — observer.
- `actor_principal_id?` — FamilyMember who performed this action; null for non-human originators.
- `triggered_by_principal_id?` — FamilyMember who initiated the chain; may be null for autonomous events.
- `subject_principal_ids[]` — may be empty.
- `owner_principal_id` — required; FamilyMember or `household` (never a ServicePrincipal).
- `room_id?`.
- `privacy_tier`.
- `publish_capability_required[]`, `subscribe_capability_required[]`.
- `audience?`, `correlation_id?`, `causation_id?`, `idempotency_key?`.
- `payload`, `timestamp`.

### Memory

A stored fact derived from one or more events.

- `id`.
- `owner_principal_id` — FamilyMember or `household`.
- `privacy_tier` — inherited from the producing event(s); see [memory-and-context.md](../02-domains/memory-and-context.md) for tightening/loosening rules.
- `provenance` — `{source_event_id, source_type, source_id, capability_used, confidence}`. Generalized so non-device origins (workflow, scheduler, agent, brain, system) are first-class.
- `embedding_ref?` — row reference to the pgvector-backed embedding table ([ADR-0003](../05-decisions/0003-vector-store.md)).
- `category` — `per-user-private` | `family-shared` | `ambient-observation` | `agent-internal`.
- `created_at`, `last_accessed_at`, `expires_at?`.

### WorkItem

Project → Feature → Task hierarchy. Like every user-visible datum, a WorkItem has owner, tier, provenance, and access policy ([principles.md](../00-orientation/principles.md) invariant #2).

- `id`, `parent_id?` (null for root projects).
- `type` — `project` | `feature` | `task`.
- `title`, `description`.
- `status` — `backlog` | `ready` | `in-progress` | `done` | `canceled`.
- `priority` — `high` | `medium` | `low`.
- `assignee_principal_id?` — may be a FamilyMember or a ServicePrincipal (e.g., `agent`).
- `dependencies` — list of WorkItem ids that block this one.
- `owner_principal_id` — FamilyMember or `household`. Required.
- `privacy_tier` — defaults to `family-shared` for household-owned items, `private-personal` for items a family member explicitly marks private. Required.
- `provenance` — `{created_by_principal_id, created_via_capability, created_at}`. The capability under which the item was created is recorded so audit can answer "how did this get here?"
- `access_policy` — derived from `owner_principal_id` + `privacy_tier`; not stored separately.
- Comments and status-transition timestamps. Comments inherit the item's privacy tier unless explicitly tightened.

### Job

A workflow run. Owner / tier / provenance / access policy apply just like any other datum.

- `id`, `workflow_name`.
- `status` — `queued` | `running` | `progressing` | `succeeded` | `failed` | `canceled`.
- `progress` — `{step, percent, message}`.
- `result_ref?` — pointer into Postgres (rows, blobs).
- `started_at`, `completed_at?`.
- `triggered_by_principal_id?` — FamilyMember who initiated the run, or null for autonomous chains.
- `owner_principal_id` — typically the same as `triggered_by`; falls back to `household` for autonomous jobs. Required.
- `privacy_tier` — inherits the most restrictive tier of the inputs the workflow processed; defaults to `family-shared`. Required.
- `provenance` — `{triggering_event_id?, scheduler_id?, capability_used}`. How the run was authorized.
- `access_policy` — derived from `owner_principal_id` + `privacy_tier`.

### AuditLog

A record of any access decision, capability change, or cross-tier read. Audit data is itself sensitive — it reveals what people asked about even when the request was denied.

- `actor_principal_id?` (or null + source fields).
- `subject_principal_ids?`.
- `action` — e.g., `memory.read`, `capability.grant`.
- `decision` — `allowed` | `denied`.
- `reason`.
- `correlation_id?`.
- `timestamp`.
- `owner_principal_id` — defaults to `household`. Required.
- `privacy_tier` — defaults to `family-shared` for routine entries; entries about a single FamilyMember's private actions are tightened to `private-personal` automatically. Required.
- `access_policy` — derived from owner + tier; **only admins (parents) may read household-owned audit logs by default**. Kids cannot read the audit log.

## Relationships

- A **Capability** links a **Device** and a **Principal** to a permission name and scope.
- An **Event** references a **Principal** in its `actor`, `subject`, and `owner` slots; a **Device** through `source_type`+`source_id`; a **Room** optionally.
- A **Memory** is provenance-linked to one or more **Events** and owned by a **Principal**.
- A **WorkItem** is owned by a FamilyMember or the Household and may be assigned to a FamilyMember or a ServicePrincipal (e.g., `agent`).
- A **Job** is triggered by a FamilyMember (or autonomous) and emits **Events** as it progresses.

## Actor / Triggered-by / Subject / Owner / Observer

These five roles can independently apply to the same event. Confusing them is the single most common source of access-control bugs.

- **Actor** — the family-member principal who **performed this specific action**. Null for events originated by system / device / scheduler / workflow / agent. There is no "system" principal value; system-ness is expressed via a null actor plus the source fields.
- **Triggered by** — the family-member principal who **initiated the chain** that led to this event. A workflow Tim queued emits events with `actor=null, triggered_by=tim`. A nightly scheduled job has `actor=null, triggered_by=null`. Lets consumers filter "events I started" without conflating with "events I performed."
- **Subject** — who the event is about. May or may not be the actor; may be empty.
- **Owner** — whose data the event becomes once stored. May be a family member or `household` (never a ServicePrincipal).
- **Observer** — the device/process that produced the event, conveyed by `source_type` + `source_id`.

### Worked examples

| Scenario | actor | triggered_by | subject | owner | observer |
|---|---|---|---|---|---|
| Kitchen Pi sees Tim (derived presence fact) | `null` | `null` | `[tim]` | `tim` | `device:kitchen-pi-01` |
| Same Pi sees an unknown face | `null` | `null` | `[]` | `household` | `device:kitchen-pi-01` |
| Workflow Tim queued emits `job.progress` | `null` | `tim` | `[]` | `tim` | `workflow:<run_id>` |
| Scheduler fires nightly reflection | `null` | `null` | `[]` | `household` | `scheduler:nightly-reflection` |
| Bennett's mobile asks for memory | `bennett` | `bennett` | `[bennett]` | `bennett` | `device:bennetts-iphone` |
| Tim sends a chat message | `tim` | `tim` | `[tim]` | `tim` | `device:tims-iphone` |

The owner is what drives storage and retention; the subject + tier drive presentation; the actor + capability set drive permission to act; triggered_by is for routing to interested clients ("show Tim everything from chains he started"); the observer drives provenance and trust.

## Design Invariants

- **Every persisted record has an owner principal.** The Household is the fallback for things without a single human owner; "no owner" is not a valid state.
- **Privacy tier travels with the data.** Memories inherit from events; aggregations downgrade only via the explicit-loosening rules in [memory-and-context.md](../02-domains/memory-and-context.md).
- **Provenance is mandatory for memories.** A memory without provenance cannot be created — this is what makes deletion-cascades and cross-tier audits possible.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres holds these entities.
- 🟢 [ADR-0003](../05-decisions/0003-vector-store.md) — pgvector stores memory embeddings in Postgres.
