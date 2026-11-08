# Birokratko

**Javni natječaji koji odgovaraju tvojoj djelatnosti.**

Birokratko za tvrtku (po OIB-u) rangira otvorene javne natječaje prema djelatnostima upisanima u Sudski registar i
objašnjava zašto je svaki natječaj na popisu (sličnost opisa, CPV područje, lokacija, preostalo vrijeme), uz povijesnu
konkurenciju. Javnom naručitelju procjenjuje koliko sposobnih dobavljača ima po županijama i kakva je konkurencija bila
dosad, prije nego što objavi nabavu.

- **Natjecanje:** Datathon Portala otvorenih podataka 2026., izazov **C: Gospodarstvo i učinkovito upravljanje**
- **Aplikacija uživo:** <!-- LIVE_URL --> (vidi [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md))
- **Licenca koda:** [EUPL-1.2](LICENSE)

## Dokumentacija

| Dokument                                                                   | Sadržaj                                                                                                  |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| [apps/nabavaradar/docs/README.md](apps/nabavaradar/docs/README.md)         | Opis aplikacije, arhitektura, izvori podataka, API, formula rangiranja, upozorenja e-poštom, ograničenja |
| [apps/nabavaradar/docs/validation.md](apps/nabavaradar/docs/validation.md) | Validacija rangiranja na 30 009 stvarnih parova pobjednik–natječaj                                       |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)                                   | Produkcijsko postavljanje (Azure VM, Docker Compose, Caddy, cron)                                        |
| [docs/FOUNDATION.md](docs/FOUNDATION.md)                                   | Zajednički paketi `opendata_core` (Python) i `@dt/ui` (React), konvencije                                |
| [docs/adr/](docs/adr/)                                                     | Arhitekturne odluke (stack, pgvector, ograničenje upita, podatkovne odluke, v2)                          |
| [apps/nabavaradar/data/evidence/](apps/nabavaradar/data/evidence/)         | Sirovi odgovori izvora s datumom dohvata (dokazi)                                                        |

## Arhitektura ukratko

```
 Sudski registar API v3   TED Search API v3   CPV 2008 (xlsx)   CKAN registri ugovora (data.gov.hr)
          │                       │                  │                    │
          └──────────── ingest (Python, Typer CLI, svakodnevno cron) ─────┘
                                  │  multilingual-e5-small embeddinzi · NKD→CPV crosswalk · statistika
                     PostgreSQL 16 + pgvector + PostGIS
                                  │
                     FastAPI /api/v1 (OpenAPI na /docs)
                                  │
                     React SPA (Vite, TypeScript)  ◄── Caddy (HTTPS, CSP, /api proxy)
```

## Korišteni skupovi podataka

| Skup podataka                                                       | Izdavatelj                                                | Poveznica                                                                  | Način pristupa                                        |
| ------------------------------------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- |
| Sudski registar – javni servis v3 (subjekti, djelatnosti, NKD)      | Ministarstvo pravosuđa, uprave i digitalne transformacije | https://sudreg-data.gov.hr/                                                | API (OAuth2), **testno okruženje, snimka 2024-06-16** |
| TED – obavijesti o nadmetanju i dodjeli ugovora (naručitelji iz RH) | Ured za publikacije EU                                    | https://ted.europa.eu/ (API `https://api.ted.europa.eu/v3/notices/search`) | API, svakodnevno                                      |
| CPV 2008 – Zajednički rječnik javne nabave                          | Ured za publikacije EU                                    | https://ted.europa.eu/documents/d/ted/cpv_2008_xls                         | preuzeta službena datoteka                            |
| Registri ugovora javne nabave (gradovi, općine)                     | razni izdavatelji na Portalu otvorenih podataka           | https://data.gov.hr/ (CKAN `package_search`)                               | CKAN API                                              |

Svaka tablica ima zapis o izvoru i vremenu dohvata (`data_source`, `ingestion_run`); aplikacija ih prikazuje na
stranici „Izvori podataka” (`/izvori`, `GET /api/v1/sources`). Detalji: [apps/nabavaradar/docs/README.md](apps/nabavaradar/docs/README.md#izvori).

## Brzi početak (lokalno)

Potrebno: Docker, [uv](https://docs.astral.sh/uv/) (Python 3.12), Node 20 + pnpm 9, make (na Windowsu iz Git Basha).

```bash
cp .env.example .env                     # postavi POSTGRES_PASSWORD, CONTACT_EMAIL, SUDREG_* i SUBSCRIPTION_SECRET
make dev                                 # PostgreSQL + pgvector, Mailpit (http://127.0.0.1:8025)
uv sync && pnpm install
make migrate
make ingest STEP=sources && make ingest STEP=cpv && make ingest STEP=sudreg && make ingest STEP=ted && make ingest STEP=derive
uv run --package nabavaradar-api uvicorn nabavaradar_api.main:app --port 8000
pnpm --filter nabavaradar-web dev        # http://localhost:5173
```

Testovi: `make test` (pytest bez mreže + vitest), `make lint`, `make build`. Testovi koriste samo stvarne snimljene
odgovore izvora (`apps/nabavaradar/api/tests/fixtures/`).

> Node 22+ ima eksperimentalni globalni `localStorage` koji u vitestu zasjeni jsdom; projekt cilja Node 20
> (`.nvmrc`, CI). Na novijem Nodeu pokreni testove s `NODE_OPTIONS=--no-experimental-webstorage`.

## Struktura

```
apps/nabavaradar/api   FastAPI + ingest CLI (paket nabavaradar_api), migracije, testovi
apps/nabavaradar/web   React SPA
apps/nabavaradar/data  dokazi (evidence) i lokalna predmemorija
packages/core          opendata_core: config, HTTP s predmemorijom, provenance, CKAN, semantic, e-pošta, API tvornica
packages/ui            @dt/ui: tokeni, Tailwind preset, pristupačne React komponente
infra/                 slika baze, Dockerfile za API i web
```

Tehnički identifikatori (`nabavaradar`) ostali su iz razvojne faze da migracije i baza rade nepromijenjeni.

## Alati otvorenog koda i umjetne inteligencije

- Stack: Python 3.12, FastAPI, SQLAlchemy, Alembic, PostgreSQL 16, PostGIS, pgvector, sentence-transformers
  (model `intfloat/multilingual-e5-small`, MIT), React 18, Vite, Tailwind, Caddy. Sve otvorenog koda.
- Pri razvoju korišten je AI asistent za programiranje **Claude Code** (Anthropic); commitovi na kojima je radio
  označeni su s `Co-Authored-By: Claude`.

## Licenca

Izvorni kod: [EUPL-1.2](LICENSE). Podaci zadržavaju licence svojih izdavatelja (vidi tablicu izvora iznad).
