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
    object_id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    type object_type NOT NULL,
    material material NOT NULL,
    UNIQUE (type, material)
);

CREATE TABLE object_subtypes (
    object_id integer REFERENCES objects (object_id) DEFERRABLE INITIALLY IMMEDIATE,
    object_subtype_id integer GENERATED ALWAYS AS IDENTITY,
    subtype text NOT NULL,
    PRIMARY KEY (object_id, object_subtype_id),
    UNIQUE (object_id, subtype)
);

CREATE TABLE genres (
    genre_id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL UNIQUE
);

CREATE TABLE periods (
    period_id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL UNIQUE,
    years int4range NOT NULL,
    super integer REFERENCES periods (period_id)
);

CREATE TABLE proveniences (
    provenience_id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    site_id text UNIQUE,
    name text,
    modern_name text,
    latitude real,
    longitude real,
    CHECK (name IS NOT NULL OR modern_name IS NOT NULL)
);

SELECT pg_catalog.pg_extension_config_dump('@extschema@.objects', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('@extschema@.objects', 'object_id'), '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.object_subtypes', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('@extschema@.object_subtypes', 'object_subtype_id'), '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.genres', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('@extschema@.genres', 'genre_id'), '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.periods', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('@extschema@.periods', 'period_id'), '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.proveniences', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('@extschema@.proveniences', 'provenience_id'), '');



CREATE OR REPLACE PROCEDURE load_context (v_path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format('COPY @extschema@.periods(period_id, name, years, super) FROM %L CSV NULL ''\N''', v_path || 'periods.csv');
EXECUTE format('COPY @extschema@.proveniences(provenience_id, site_id, name, modern_name, latitude, longitude) FROM %L CSV NULL ''\N''', v_path || 'proveniences.csv');
EXECUTE format('COPY @extschema@.genres(genre_id, name) FROM %L CSV NULL ''\N''', v_path || 'genres.csv');
EXECUTE format('COPY @extschema@.objects(object_id, type, material) FROM %L CSV NULL ''\N''', v_path || 'objects.csv');
EXECUTE format('COPY @extschema@.object_subtypes(object_id, object_subtype_id, subtype) FROM %L CSV NULL ''\N''', v_path || 'object_subtypes.csv');

PERFORM setval(pg_get_serial_sequence('@extschema@.periods', 'period_id'), max(period_id)) FROM @extschema@.periods;
PERFORM setval(pg_get_serial_sequence('@extschema@.proveniences', 'provenience_id'), max(provenience_id)) FROM @extschema@.proveniences;
PERFORM setval(pg_get_serial_sequence('@extschema@.genres', 'genre_id'), max(genre_id)) FROM @extschema@.genres;
PERFORM setval(pg_get_serial_sequence('@extschema@.objects', 'object_id'), max(object_id)) FROM @extschema@.objects;
PERFORM setval(pg_get_serial_sequence('@extschema@.object_subtypes', 'object_subtype_id'), max(object_subtype_id)) FROM @extschema@.object_subtypes;

END

$BODY$;