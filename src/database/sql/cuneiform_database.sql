CREATE TABLE corpora (
    corpus_id serial PRIMARY KEY,
    name_short text NOT NULL UNIQUE,
    name_long text NOT NULL,
    core boolean NOT NULL
);


-- Texts

CREATE TABLE texts (
    text_id serial PRIMARY KEY,
    cdli_no text,
    bdtns_no text,
    citation text,
    provenience_id integer REFERENCES proveniences (provenience_id) DEFERRABLE INITIALLY IMMEDIATE,
    provenience_comment text,
    period_id integer REFERENCES periods (period_id) DEFERRABLE INITIALLY IMMEDIATE,
    period_comment text,
    genre_id integer REFERENCES genres (genre_id) DEFERRABLE INITIALLY IMMEDIATE,
    genre_comment text,
    date TABLETDATE,
    archive text
);


CREATE TABLE transliterations (
    transliteration_id serial PRIMARY KEY,
    text_id integer NOT NULL REFERENCES texts (text_id) DEFERRABLE INITIALLY IMMEDIATE,
    corpus_id integer NOT NULL REFERENCES corpora (corpus_id) DEFERRABLE INITIALLY IMMEDIATE
);


-- Compositions

CREATE TABLE compositions (
    composition_id SERIAL PRIMARY KEY,
    composition_name text UNIQUE NOT NULL
);

CREATE TYPE witness_type AS ENUM (
    'original',
    'print',
    'copy',
    'variant'
);


-- Corpus

CREATE TYPE object_type AS ENUM (
    'tablet',
    'envelope',
    'seal',
    'object'
);

CREATE TYPE surface_type AS ENUM (
    'obverse',
    'reverse',
    'top',
    'bottom',
    'left',
    'right',
    'seal',
    'fragment',
    'surface'
);

CREATE TYPE block_type AS ENUM (
    'column',
    'summary',
    'date',
    'caption',
    'legend',
    'bottom_column',
    'block'
);


CREATE OR REPLACE PROCEDURE create_corpus (schema text)
    LANGUAGE PLPGSQL
    AS 
$BODY$

BEGIN

EXECUTE format(
    $$
    CREATE TABLE %1$I.sections (
        transliteration_id integer,
        section_no integer NOT NULL,
        section_name text NOT NULL,
        composition_id integer NOT NULL REFERENCES compositions (composition_id) DEFERRABLE INITIALLY IMMEDIATE,
        witness_type witness_type NOT NULL,
        PRIMARY KEY (transliteration_id, section_no)
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.compounds (
        transliteration_id integer,
        compound_no integer,
        pn_type pn_type,
        language LANGUAGE,
        section_no integer,
        compound_comment text,
        PRIMARY KEY (transliteration_id, compound_no),
        FOREIGN KEY (transliteration_id, section_no) REFERENCES %1$I.sections (transliteration_id, section_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.words (
        transliteration_id integer,
        word_no integer,
        compound_no integer NOT NULL,
        capitalized boolean,
        PRIMARY KEY (transliteration_id, word_no),
        FOREIGN KEY (transliteration_id, compound_no) REFERENCES %1$I.compounds (transliteration_id, compound_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.objects (
        transliteration_id integer,
        object_no integer,
        object_type object_type NOT NULL,
        object_data text,
        object_comment text,
        PRIMARY KEY (transliteration_id, object_no)
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.surfaces (
        transliteration_id integer,
        surface_no integer,
        object_no integer NOT NULL,
        surface_type surface_type NOT NULL,
        surface_data text,
        surface_comment text,
        PRIMARY KEY (transliteration_id, surface_no),
        FOREIGN KEY (transliteration_id, object_no) REFERENCES %1$I.objects (transliteration_id, object_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.blocks (
        transliteration_id integer,
        block_no integer,
        surface_no integer NOT NULL,
        block_type block_type NOT NULL,
        block_data text,
        block_comment text,
        PRIMARY KEY (transliteration_id, block_no),
        FOREIGN KEY (transliteration_id, surface_no) REFERENCES %1$I.surfaces (transliteration_id, surface_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.lines (
        transliteration_id integer,
        line_no integer,
        block_no integer NOT NULL,
        line text,
        line_comment text,
        PRIMARY KEY (transliteration_id, line_no),
        FOREIGN KEY (transliteration_id, block_no) REFERENCES %1$I.blocks (transliteration_id, block_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.corpus (
        transliteration_id integer,
        sign_no integer,
        line_no integer NOT NULL,
        word_no integer NOT NULL,
        value_id integer REFERENCES values DEFERRABLE INITIALLY IMMEDIATE,
        sign_variant_id integer REFERENCES sign_variants DEFERRABLE INITIALLY IMMEDIATE,
        custom_value text,
        type sign_type NOT NULL,
        indicator_type indicator_type,
        phonographic boolean,
        stem boolean,
        condition sign_condition NOT NULL,
        crits text,
        comment text,
        newline boolean NOT NULL,
        inverted boolean NOT NULL,
        ligature boolean NOT NULL,
        PRIMARY KEY (transliteration_id, sign_no),
        FOREIGN KEY (transliteration_id, word_no) REFERENCES %1$I.words (transliteration_id, word_no) DEFERRABLE INITIALLY IMMEDIATE,
        FOREIGN KEY (transliteration_id, line_no) REFERENCES %1$I.lines (transliteration_id, line_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

END;

$BODY$;

CALL create_corpus('@extschema@');

ALTER TABLE compounds ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE words ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE objects ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE surfaces ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE blocks ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE lines ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE corpus ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;

CLUSTER corpus USING corpus_pkey;


-- Performance

CREATE OR REPLACE PROCEDURE database_create_indexes ()
LANGUAGE SQL
AS $BODY$
    CREATE INDEX texts_provenience_id_ix ON @extschema@.texts(provenience_id);
    CREATE INDEX texts_period_id_ix ON @extschema@.texts(period_id);
    CREATE INDEX texts_genre_id_ix ON @extschema@.texts(genre_id);
$BODY$;

CREATE OR REPLACE PROCEDURE database_drop_indexes ()
LANGUAGE SQL
AS $BODY$
    DROP INDEX @extschema@.texts_provenience_id_ix;
    DROP INDEX @extschema@.texts_period_id_ix;
    DROP INDEX @extschema@.texts_genre_id_ix;
$BODY$;

CALL database_create_indexes ();


SELECT pg_catalog.pg_extension_config_dump('@extschema@.corpora', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.texts', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.transliterations', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.compositions', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.sections', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.compounds', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.words', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.objects', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.surfaces', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.blocks', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.lines', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.corpus', '');