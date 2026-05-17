# Overview

## Purpose

Build a self-hosted personal AI assistant for the Ritzema family — Tim, Laurie, Bennett, Drew, David, William — that runs on owned hardware and treats cloud LLMs as a bootstrap accelerator, not a destination.

## What this is

A single-household system, intended to be operated and maintained by the household itself. Compute lives on hardware Tim owns: a Mac Studio in the garage as the brain (initially); `mac-mini-1` as the Postgres + pgvector database host; Raspberry Pis with cameras as static installs and avatars; mobile phones and laptops as personal clients.

The assistant is **family-aware from day one**. Even before Laurie or the kids onboard, the data model, identity layer, privacy tiers, and capability checks are already in place. Phase 0 is "single active user, family-aware foundation," not "single-user architecture, retrofit later."

## Non-goals

- **Multi-family.** This system is not a SaaS or a shared hosted service. If another family wants something similar, they install their own instance on their own hardware.
- **Public-facing AI.** No untrusted clients, no anonymous access, no public endpoints beyond what's needed for the family to reach their own instance.
- **Training data sharing.** Family conversations, observations, and memories never leave owned infrastructure for the purpose of model training. The cloud egress policy in [ai-orchestration.md](../01-architecture/ai-orchestration.md) governs the narrow cases when data may leave at all.

## Design influences

This project draws **concepts** — not code, not technology choices — from two prior repos:

- **local-vida** — mature concept POC. Source for event-driven architecture, work-item hierarchy, autonomous task heartbeat, tiered LLM routing, and tool abstraction.
- **mia-sempre** — architectural sketch. Source for persistent agent runtime loops, multi-user context isolation, local-first AI commitment, and the HDTS brain-to-nerve hierarchy (held as a future architectural influence, not a day-one requirement).

See [99-reference/concept-attribution.md](../99-reference/concept-attribution.md) for the full mapping of what was kept, adapted, deferred, or rejected.
