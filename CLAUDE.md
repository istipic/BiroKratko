# CLAUDE.md — Birokratko

Birokratko (technical name `nabavaradar`): open public tenders matched to company activities, built for the
Croatian "Datathon Portala otvorenih podataka 2026", challenge C. Standalone repository.

## WORKING RULES (apply to every task)

1. Inspect before changing: run `git status`, list the tree (depth 3), read docs/FOUNDATION.md and apps/nabavaradar/docs/ before editing.
2. Preserve working functionality. No rewrites of working code unless a test proves a defect.
3. Implement in small steps. After each meaningful step run the relevant tests and commit (Conventional Commits).
4. Never invent API endpoints, parameters, field names, credentials, datasets or data values. Probe the real source, save evidence (raw response with date) under apps/nabavaradar/data/evidence/, then code against it.
5. No fake, sample or demo data in production code paths. Tests use recorded REAL responses saved as tests/fixtures/<source>/<YYYY-MM-DD>_<name>.<ext>. Never present cached or stale data as live: always expose retrieval time.
6. Every table loaded from an external source has a data_source row and an ingestion_run row (opendata_core.provenance).
7. Do not add dependencies beyond the fixed stack unless essential; if you add one, record why in docs/adr/.
8. Secrets only in .env (gitignored); keep .env.example current; never print secrets in logs.
9. UI text in Croatian (hr), code and comments in English.
10. Never claim something works without running it.
11. Respect source usage policies: identifying User-Agent with contact email, rate limits, caching.

## Quick reference

- Docs: README.md, apps/nabavaradar/docs/, docs/FOUNDATION.md, docs/DEPLOYMENT.md, decisions in docs/adr/.
- Python: uv workspace (`uv sync`, `uv run pytest apps/nabavaradar/api`). Core package: `opendata_core`.
- Web: pnpm workspace (`pnpm --filter nabavaradar-web dev|build|test`). Shared UI: `@dt/ui`.
- Local infra: `make dev` (PostgreSQL 16 + PostGIS + pgvector, Mailpit).
