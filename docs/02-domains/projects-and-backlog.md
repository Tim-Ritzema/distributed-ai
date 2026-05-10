# Projects and Backlog

## Purpose

A long-term project management surface for the family, plus the Jarvis pattern: tossing work to the AI and letting an autonomous loop pick it up.

## Work-item model

Borrowed in concept from local-vida. A three-tier hierarchy in a single `work_items` table, distinguished by `type`:

```
Project (root)
   └── Feature
         └── Task
```

A WorkItem has (full field list lives in [01-architecture/data-model.md](../01-architecture/data-model.md)):

- `id`, `parent_id?` (null for projects).
- `type` — `project` | `feature` | `task`.
- `title`, `description`.
- `status` — `backlog` | `ready` | `in-progress` | `done` | `canceled`.
- `priority` — `high` | `medium` | `low`.
- `assignee_principal_id?` — a FamilyMember or a ServicePrincipal (e.g., `agent`).
- `dependencies` — other WorkItem ids that block this one.
- `owner_principal_id` — FamilyMember or `household`. Required.
- `privacy_tier` — defaults to `family-shared` for household-owned items, `private-personal` for items the owner explicitly marks private. Required.
- `provenance` — `{created_by_principal_id, created_via_capability, created_at}`.
- `access_policy` — derived from owner + tier; not stored separately.
- `started_at?`, `completed_at?`, status-transition timestamps.
- Comments (notes with author attribution; inherit the item's privacy tier unless explicitly tightened).

Status transitions auto-set timestamps: `in-progress` sets `started_at`; `done`/`canceled` set `completed_at`.

## API surface

Standard HTTP CRUD ([api-and-transport.md](../01-architecture/api-and-transport.md)):

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/work-items` | Create a project, feature, or task. |
| `GET` | `/work-items/{id}` | Read one. |
| `GET` | `/work-items/{id}/tree` | Read the full hierarchy. |
| `PATCH` | `/work-items/{id}` | Update title, status, priority, assignee. |
| `POST` | `/work-items/{id}/dependencies` | Add a blocking relationship. |
| `POST` | `/work-items/{id}/comments` | Add a comment. |
| `GET` | `/work-items/agent-queue` | The AI's current actionable queue. |

All endpoints capability-gated. A kid cannot list a parent's private work items; the agent's queue endpoint requires an admin or self-issued capability.

Live progress on items the AI is working on flows over WebSocket (see [background-processing.md](background-processing.md) for job progress events).

## The Jarvis pattern

Borrowed from local-vida. The AI can autonomously execute work items assigned to it.

**Heartbeat loop:**

1. The Brain runs a periodic heartbeat (concept from local-vida — order of every 60 seconds).
2. Heartbeat queries WorkItems with `assignee_principal_id=agent` and `status=ready` and no unmet dependencies.
3. For each item: spawn a workflow run with a bounded toolset and the item context.
4. Item transitions to `in-progress`; workflow events stream as the work proceeds (Flow 2 in [example-flows.md](../01-architecture/example-flows.md)).
5. On completion: workflow updates the item to `done` (or `canceled` on failure), often creates a follow-up item with results.

**Bounded toolset.** Day-one, the agent's autonomous toolset is limited to read-only research operations (WebSearch + WebFetch), mirroring local-vida's safety boundary. Tools that take actions in the wider world (sending email, committing code, paying bills) require explicit capability grants and may require human-in-the-loop approval (see [background-processing.md](background-processing.md)).

## Owner and assignee

These are independent concepts:

- **Owner** drives access and retention. A project Tim creates is `owner=tim`.
- **Assignee** drives execution. A task may be assigned to Laurie (who'll do it), the agent (who'll attempt it autonomously), or unassigned.

A kid can assign tasks to themselves but not to a parent. A parent can assign anywhere.

## Cross-references

- Live progress: [background-processing.md](background-processing.md).
- Capability examples for work-item access: [security-and-privacy.md](security-and-privacy.md).
- End-to-end walkthrough: [example-flows.md](../01-architecture/example-flows.md) flow #2.

## Design Invariants

- **Hierarchy is single-parent.** A task has one feature; a feature has one project. Cross-project linking happens via comments or future tags, not parent edges.
- **Dependencies don't cross owners without acknowledgment.** A dependency from Bennett's task to one of Tim's tasks requires Tim to acknowledge — otherwise Bennett can block Tim's queue.
- **The agent's queue is bounded.** Only items in `ready` state with `assignee=agent` and no unmet dependencies. A non-ready item is invisible to the heartbeat.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — work items live in Postgres.

## Open Questions

- Tags / labels. Probably useful, deferred until pattern emerges.
- Recurring tasks. Probably useful, deferred. The heartbeat could re-create from a template.
- Estimates and time-tracking. Out of scope until clearly needed.
