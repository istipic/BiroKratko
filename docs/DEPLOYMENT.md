# Produkcijsko postavljanje

Birokratko radi na jednom virtualnom stroju s Docker Composeom: iste slike i ista konfiguracija kao lokalno, razlikuje se
samo `.env`. Obrazloženje izbora: [ADR 0010](adr/0010-standalone-repository-and-azure-deployment.md).

## Trenutna instalacija

| Stavka          | Vrijednost                                                                                          |
| --------------- | --------------------------------------------------------------------------------------------------- |
| Adresa          | https://birokratko-hr.spaincentral.cloudapp.azure.com                                               |
| Platforma       | Microsoft Azure (Azure for Students), regija Spain Central                                          |
| Virtualni stroj | `Standard_B2as_v2` (2 vCPU, 8 GB RAM) + 4 GB swap, Ubuntu 24.04 LTS, disk 64 GB                     |
| Resursi         | grupa `birokratko-rg`, VM `birokratko-vm`, DNS oznaka `birokratko-hr`                               |
| Mapa na serveru | `/opt/birokratko` (klon ovog repozitorija), tajne u `/opt/birokratko/.env` (nije u gitu, prava 600) |
| TLS             | Caddy automatski dohvaća i obnavlja Let's Encrypt certifikat za DNS ime                             |

## Komponente (`docker-compose.prod.yml`)

| Servis            | Uloga                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `db`              | PostgreSQL 16 + PostGIS + pgvector (`infra/db`), podaci u volumenu `pgdata`                |
| `nabavaradar-api` | FastAPI (`uvicorn`), model `multilingual-e5-small` u volumenu `nabavaradar-data` (`/data`) |
| `nabavaradar-web` | jednokratno kopira izgrađeni React SPA u volumen `srv`                                     |
| `caddy`           | HTTPS, sigurnosna zaglavlja (CSP), statične datoteke i `/api` proxy prema API-ju           |

## Postavljanje od nule

```bash
# 1) Azure (lokalno, Azure CLI)
az login
az group create -n birokratko-rg -l francecentral
az vm create -g birokratko-rg -n birokratko-vm -l spaincentral \
  --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B2as_v2 \
  --admin-username azureuser --ssh-key-values ~/.ssh/birokratko_azure.pub \
  --public-ip-sku Standard --public-ip-address-dns-name birokratko-hr --os-disk-size-gb 64
az vm open-port -g birokratko-rg -n birokratko-vm --port 80,443 --priority 900

# 2) Server
curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker azureuser
sudo apt-get install -y make
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
git clone https://github.com/istipic/BiroKratko.git /opt/birokratko && cd /opt/birokratko
cp .env.example .env   # POSTGRES_PASSWORD, SUBSCRIPTION_SECRET (openssl rand -hex 32), CONTACT_EMAIL,
                       # SUDREG_*, SMTP_*, NABAVA_HOST=<dns ime>; chmod 600 .env

# 3) Podaci: ili vraćanje dumpa ...
docker compose -f docker-compose.prod.yml up -d db
docker compose -f docker-compose.prod.yml exec -T db pg_restore -U postgres -d nabavaradar --no-owner < nabavaradar.dump
# ... ili učitavanje iz izvora (vidi apps/nabavaradar/docs/README.md, "Pokretanje")
make migrate PROD=1
make ingest PROD=1 STEP=sources   # zatim cpv, sudreg, ted, derive

# 4) Pokretanje cijelog stacka
GIT_SHA=$(git rev-parse --short HEAD) docker compose -f docker-compose.prod.yml up -d --build

# 5) Raspored (svakodnevno osvježavanje TED-a, derive, upozorenja, tjedni sažetak)
crontab apps/nabavaradar/deploy/crontab
```

Dump lokalne baze: `docker compose exec -T db pg_dump -U postgres -Fc nabavaradar > nabavaradar.dump`. Prije
objave iz dumpa su obrisane lokalne testne pretplate (`subscription`, `alert_sent`, `alert_exclusion`).

## Ažuriranje

```bash
make deploy DEPLOY_HOST=azureuser@birokratko-hr.spaincentral.cloudapp.azure.com
# = ssh + git pull --ff-only + docker compose up -d --build
```

## Provjera

```bash
curl -s https://birokratko-hr.spaincentral.cloudapp.azure.com/health
curl -s https://birokratko-hr.spaincentral.cloudapp.azure.com/api/v1/status
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f nabavaradar-api
```

## E-pošta

**Trenutno stanje (2026-11-09): SMTP u produkciji nije postavljen.** Sve ostale funkcije rade; prijava na
upozorenja vraća poruku „Slanje poruke trenutno nije moguće. Pokušajte kasnije.” (HTTP 503), a pretplata se ne
aktivira. Kad se postave podaci za SMTP, upozorenja rade bez izmjene koda.

Potvrde pretplate i upozorenja šalju se preko SMTP-a (`SMTP_HOST`, `SMTP_PORT=587` sa STARTTLS, `SMTP_USER`,
`SMTP_PASSWORD`, `SMTP_FROM`). Lokalno se koristi Mailpit; u produkciji je potreban stvarni SMTP poslužitelj. Nakon
izmjene `.env`: `docker compose -f docker-compose.prod.yml up -d nabavaradar-api`.

## Troškovi i gašenje

VM se plaća iz kredita Azure for Students. Nakon natjecanja:
`az vm deallocate -g birokratko-rg -n birokratko-vm` (zaustavlja naplatu računanja) ili
`az group delete -n birokratko-rg` (briše sve resurse).
