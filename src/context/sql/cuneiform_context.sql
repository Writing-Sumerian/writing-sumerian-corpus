CREATE TYPE tabletdate AS (
    king text,
    y text,
    m text,
    d text
);

CREATE TABLE genres (
    genre_id serial PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE periods (
    period_id serial PRIMARY KEY,
    name text NOT NULL UNIQUE,
    years int4range NOT NULL,
    super integer REFERENCES periods (period_id)
);

CREATE TABLE proveniences (
    provenience_id serial PRIMARY KEY,
    site_id text UNIQUE,
    name text,
    modern_name text,
    latitude real,
    longitude real,
    CHECK (name IS NOT NULL OR modern_name IS NOT NULL)
);

SELECT pg_catalog.pg_extension_config_dump('@extschema@.genres', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.periods', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.proveniences', '');