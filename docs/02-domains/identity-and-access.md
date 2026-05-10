# Identity and Access

## Purpose

Define who the system recognizes as a principal, what default access rules apply, and how this is enforced from Phase 0.

## Principals

Principals come in two flavors:

- **Family members** — human principals: Tim, Laurie, Bennett, Drew, David, William. Each has a `role` of `parent` or `kid`. Identified by lowercase stable IDs (`tim`, `laurie`, ...).
- **Household** — the singleton non-human principal that owns family-shared data, room-occupancy facts, and observations whose subject is unknown. Identified as `household`.

Every persisted record has an owner principal — one of the above. There is no anonymous data and no system-level data without an owner.

## Roles

### Parent (`tim`, `laurie`)

- Full read on own private data.
- Full read on Household-scoped data.
- **Privileged read** on kid-related data (kid private memories, kid presence, kid work items). Documented explicitly here, not implicit.
- Full admin: can grant/revoke capabilities, approve device pairings, change family-member roles.

### Kid (`bennett`, `drew`, `david`, `william`)

- Full read on own private data.
- Read on Household-scoped data at `family-shared` or less sensitive tiers.
- **Cannot read parents' or siblings' private data.** Default-deny; no exceptions without explicit per-action capability grant from a parent.
- No admin actions.

## Default rules

These are the rules that hold before any custom capability grants:

| Action | Tim/Laurie | A kid (e.g., Bennett) |
|---|---|---|
| Read own private memory | allowed | allowed |
| Read sibling's private memory | n/a | denied |
| Read parent's private memory | n/a | denied |
| Read household family-shared data | allowed | allowed |
| Read kid's private memory | allowed (logged) | n/a |
| Grant a capability | allowed | denied |
| Approve a new device pairing | allowed | denied |
| Pair a personal device for self | allowed | allowed (subject to admin approval) |

Every cross-principal read (parent reading kid data) is **audit-logged**.

## The Household principal

`household` is read-accessible by all family members for `family-shared` or less sensitive tiers (`family-shared`, `room-safe`, `public-ambient`). Only admins (parents) can grant Household-scoped capabilities. This makes Household the right owner for things like:

- The shared family calendar.
- Room occupancy facts (`kitchen has 2 people`).
- Unknown-face observations.
- Family-wide preferences and settings.
- Static-installation configuration.

## Static installations: a special role

A static install (wall-mounted Pi with camera and avatar) operates under a constrained capability set even when it has identified a known person. See [security-and-privacy.md](security-and-privacy.md) — the "rash problem" — for why. In short: identifying Tim does not grant the kitchen display the right to surface Tim's private data, because others may be in earshot.

## Phase 0 invariant

**The full identity model exists from day one.** Even when only Tim is actively using a client, the database has all six family members, the Household principal, the role assignments, and the default rules. Phase 0 is "single active user, family-aware foundation," not "single-user architecture, retrofit later." Retrofitting access control after the fact is how production systems leak data.

## Design Invariants

- **No anonymous principal.** Every authenticated session resolves to a registered family member or a system component running under explicit identity.
- **Default-deny across principals.** A kid asking about a parent's data is denied unless an explicit capability says otherwise.
- **Cross-principal reads are audit-logged.** Even allowed ones.
- **Roles are not capabilities.** Roles are starting points. Capabilities are the actual gating mechanism (see [security-and-privacy.md](security-and-privacy.md) and [client-registration.md](client-registration.md)).

## Open Questions

- What happens when a kid turns 18? For now: nothing automatic. Role changes are an admin decision. Revisit when the eldest approaches that age.
- Spousal access boundaries. Default has Tim and Laurie with parallel parent access; refine if needed.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres holds the principal records and capability grants.
