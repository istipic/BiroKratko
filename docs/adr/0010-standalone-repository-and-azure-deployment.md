# ADR 0010: Standalone repository and deployment on an Azure VM

- Status: accepted
- Date: 2026-11-09

## Context

The Datathon rules require a separate application and a separate solution for each challenge. Birokratko was developed
in a monorepo next to two other apps (Blizu, Otporko) that share `opendata_core` and `@dt/ui`. The solution must also be
reachable on the internet and behave exactly as it does locally.

## Decision 1: split with history, keep the internal layout

The repository was created with `git filter-repo --invert-paths` from the monorepo, dropping `apps/blizu`, `apps/otporno`
and their ADRs, so the commit history of Birokratko and the shared packages is kept. The internal layout
(`apps/nabavaradar`, `packages/core`, `packages/ui`, `infra/`) is unchanged, so migrations, Dockerfiles, tests and
documentation links keep working. The shared packages are copied as they were; modules that only the other apps used
(`geocode`, `popgrid`, `optimize`) stay, because removing them would mean changing tested code without a defect.
Lock files were regenerated only to drop the removed workspace members (no version changed).

## Decision 2: one Azure VM with Docker Compose, not Vercel

- The API loads `multilingual-e5-small` (sentence-transformers + PyTorch) and keeps the open-tender index in memory;
  it needs about 2 GB of RAM and a long-running process. Serverless platforms (Vercel functions: 250 MB bundle limit,
  no persistent process) cannot run it, and the database needs pgvector + PostGIS.
- Free container tiers (512 MB RAM, sleeping after inactivity) cannot hold the model and would not answer the jury
  reliably.
- An Ubuntu VM on Azure for Students runs the same `docker-compose.prod.yml` as any other server: PostgreSQL with
  pgvector, the API, the static SPA and Caddy with an automatic Let's Encrypt certificate for the Azure DNS name.
  The loaded database is moved with `pg_dump`/`pg_restore`; the daily TED update, `derive` and e-mail jobs run from the
  host crontab (`apps/nabavaradar/deploy/crontab`).

## Consequences

- The live site and a local run use identical images and configuration; only `.env` differs.
- Cost is covered by the Azure for Students credit; the VM has to be stopped or deleted after the competition.
