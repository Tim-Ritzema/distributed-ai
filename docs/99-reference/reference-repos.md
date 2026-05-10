# Reference Repos

Two prior projects inform distributed-ai. They are **concept sources**, not technology commitments — see [concept-attribution.md](concept-attribution.md) for the kept/adapted/deferred/rejected breakdown.

## local-vida

- **GitHub:** https://github.com/Tim-Ritzema/local-vida
- **Local clone:** `/Users/timrossi/Desktop/CODE/local-vida`
- **What it is:** A mature single-user concept POC. The most working code among the references.
- **Stack (do not assume for distributed-ai):** Python 3.12, FastAPI, SQLAlchemy + Alembic, PostgreSQL, Qdrant, Valkey 8 (streams), LiteLLM, Prefect 3.6.9, MCP via FastMCP, Ollama, SearXNG. Frontend SvelteKit + Svelte 5 + Tailwind 4.

### Worth visiting

- `backend/src/services/event_bus.py` — event-driven flows over Valkey Streams with priority lanes.
- `backend/src/flows/heartbeat.py` — the autonomous task heartbeat (the "Jarvis pattern").
- `backend/src/database/models/work_item.py` — Project → Feature → Task hierarchy with dependencies.
- `backend/src/services/model_router.py` + `backend/src/services/classification.py` — LiteLLM-style tiered routing.
- `backend/src/services/mcp_client.py` — MCP tool abstraction.
- `docs/mia-cognitive-architecture.md` — comprehensive (~1300 lines) walkthrough of the cognitive architecture.
- `docs/task-management-flow.md` — work-item API reference.
- `docs/heartbeat-system-mia-docs.md` — autonomous execution flow design.
- `CLAUDE.md` — setup, ports, safety guards, MCP tool list.

## mia-sempre

- **GitHub:** https://github.com/Tim-Ritzema/mia-sempre
- **Local clone:** `/Users/timrossi/Desktop/CODE/mia-sempre`
- **What it is:** An architectural sketch with partial implementation. More design than code; the ideas are valuable even where the code is incomplete.
- **Stack (do not assume for distributed-ai):** Python 3.12+, FastAPI, Valkey, PostgreSQL, Qdrant, Prefect 3.6.9, LiteLLM, Langfuse.

### Worth visiting

- `docs/feature-notes/architecture.md` — comprehensive architectural design (~668 lines, primary reference for distributed-ai). Covers Agent Runtime, Momma Mia synthesis, Event Bus, Context Model, Prefect, HDTS, Model Routing, Observability.
- `docs/feature-notes/architecture.md` lines 27–474 — the **HDTS (Hierarchical Delegation with Temporal Stratification)** design. Primary source for [01-architecture/brain-to-nerve.md](../01-architecture/brain-to-nerve.md).
- `docs/mia-design-doc-v2.docx` — full HDTS design doc (Word format).
- `backend/src/services/valkey.py` — consumer-group pattern for the event bus.
- `backend/src/runtime/agent_runtime.py` — the persistent agent runtime with event/idle/maintenance loops.
- `backend/src/runtime/aspect_processor.py` — aspect-based parallel reasoning (the "Momma Mia synthesis" pattern).
- `README.md` — current status and quick start.

## Why the distinction matters

local-vida shows that the patterns work in code; mia-sempre shows what the system might look like at a deeper architectural level. distributed-ai takes concepts from both but makes its own technology decisions through ADRs in [05-decisions/](../05-decisions/).

When a doc here references either repo, it's pulling the concept, not the implementation. See [concept-attribution.md](concept-attribution.md) for the explicit mapping.
