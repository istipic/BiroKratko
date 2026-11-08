-- Birokratko database (PostgreSQL 16 + PostGIS + pg_trgm + pgvector).
-- Runs once on first initialisation of the data volume (psql, so \connect works).

CREATE DATABASE nabavaradar;

\connect nabavaradar
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS vector;
