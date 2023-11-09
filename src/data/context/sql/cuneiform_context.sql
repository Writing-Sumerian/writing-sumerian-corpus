CREATE TYPE object_type AS ENUM (
    'tablet',
    'envelope',
    'seal',
    'seal impression',
    'cone',
    'brick',
    'bulla',
    'tag',
    'vessel',
    'statue',
    'figurine',
    'plaque',
    'weight',
    'stele/boulder',
    'cylinder/prism',
    'brick stamp',
    'weapon',
    'jewellery',
    'door socket',
    'fragment',
    'other'
);

CREATE TYPE material AS ENUM (
    'bitumen',
    'clay',
    'metal',
    'shell',
    'stone'
);

CREATE TABLE objects (
    object_id serial PRIMARY KEY,
    type object_type NOT NULL,
    material material NOT NULL,
    UNIQUE (type, material)
);

CREATE TABLE object_subtypes (
    object_id serial REFERENCES objects (object_id) DEFERRABLE INITIALLY IMMEDIATE,
    object_subtype_id serial,
    subtype text NOT NULL,
    PRIMARY KEY (object_id, object_subtype_id),
    UNIQUE (object_id, subtype)
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

SELECT pg_catalog.pg_extension_config_dump('@extschema@.objects', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.object_subtypes', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.genres', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.periods', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.proveniences', '');



CREATE OR REPLACE PROCEDURE load_context (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format('COPY periods(period_id, name, years, super) FROM %L CSV NULL ''\N''', path || 'periods.csv');
EXECUTE format('COPY @extschema@.proveniences(provenience_id, site_id, name, modern_name, latitude, longitude) FROM %L CSV NULL ''\N''', path || 'proveniences.csv');
EXECUTE format('COPY @extschema@.genres(genre_id, name) FROM %L CSV NULL ''\N''', path || 'genres.csv');
EXECUTE format('COPY @extschema@.objects(object_id, type, material) FROM %L CSV NULL ''\N''', path || 'objects.csv');
EXECUTE format('COPY @extschema@.object_subtypes(object_id, object_subtype_id, subtype) FROM %L CSV NULL ''\N''', path || 'object_subtypes.csv');

PERFORM setval('periods_period_id_seq', max(period_id)) FROM periods;
PERFORM setval('proveniences_provenience_id_seq', max(provenience_id)) FROM proveniences;
PERFORM setval('genres_genre_id_seq', max(genre_id)) FROM genres;
PERFORM setval('objects_object_id_seq', max(object_id)) FROM objects;
PERFORM setval('object_subtypes_object_subtype_id_seq', max(object_subtype_id)) FROM object_subtypes;

END

$BODY$;