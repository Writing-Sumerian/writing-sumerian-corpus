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



CREATE OR REPLACE PROCEDURE load_context (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

CREATE TEMPORARY TABLE periods_tmp_ (
    period_id integer DEFAULT nextval('@extschema@.periods_period_id_seq'),
    name text,
    start_year integer,
    end_year integer,
    super_name text
);

EXECUTE format('COPY periods_tmp_(name, start_year, end_year, super_name) FROM %L CSV NULL ''\N''', path || 'periods.csv');

INSERT INTO @extschema@.periods
SELECT
    a.period_id,
    a.name,
    int4range(a.end_year, a.start_year),
    super.period_id
FROM
    periods_tmp_ a
    LEFT JOIN periods_tmp_ super ON a.super_name = super.name;

DROP TABLE periods_tmp_;

EXECUTE format('COPY @extschema@.proveniences(site_id, name, modern_name, latitude, longitude) FROM %L CSV NULL ''\N''', path || 'proveniences.csv');

EXECUTE format('COPY @extschema@.genres(name) FROM %L CSV NULL ''\N''', path || 'genres.csv');

END

$BODY$;