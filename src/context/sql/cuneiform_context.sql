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
    name text UNIQUE,
    modern_name text UNIQUE,
    latitude real,
    longitude real,
    CHECK (name IS NOT NULL OR modern_name IS NOT NULL)
);