CALL create_corpus('@extschema@');


CREATE TABLE corpora (
    corpus_id serial PRIMARY KEY,
    name_short text NOT NULL UNIQUE,
    name_long text NOT NULL,
    core boolean NOT NULL
);


CREATE TABLE ensembles (
    ensemble_id serial PRIMARY KEY,
    ensemble text
);


CREATE TABLE texts (
    text_id serial PRIMARY KEY,
    ensemble_id integer NOT NULL REFERENCES ensembles (ensemble_id) DEFERRABLE INITIALLY IMMEDIATE,
    cdli_no text,
    bdtns_no text,
    citation text,
    provenience_id integer REFERENCES proveniences (provenience_id) DEFERRABLE INITIALLY IMMEDIATE,
    provenience_comment text,
    period_id integer REFERENCES periods (period_id) DEFERRABLE INITIALLY IMMEDIATE,
    period_year integer,
    period_comment text,
    genre_id integer REFERENCES genres (genre_id) DEFERRABLE INITIALLY IMMEDIATE,
    genre_comment text,
    object_id integer REFERENCES objects (object_id) DEFERRABLE INITIALLY IMMEDIATE,
    object_subtype_id integer,
    object_comment text,
    archive text,
    FOREIGN KEY (object_id, object_subtype_id) REFERENCES object_subtypes (object_id, object_subtype_id)
);


CREATE TABLE transliterations (
    transliteration_id serial PRIMARY KEY,
    text_id integer NOT NULL REFERENCES texts (text_id) DEFERRABLE INITIALLY IMMEDIATE,
    corpus_id integer NOT NULL REFERENCES corpora (corpus_id) DEFERRABLE INITIALLY IMMEDIATE
);


CREATE TABLE compositions (
    composition_id SERIAL PRIMARY KEY,
    composition_name text UNIQUE NOT NULL
);


ALTER TABLE compounds ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE words ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE surfaces ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE blocks ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE lines ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE corpus ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE sections ADD FOREIGN KEY (composition_id) REFERENCES compositions (composition_id) DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE sections ADD FOREIGN KEY (transliteration_id) REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE;

CLUSTER corpus USING corpus_pkey;


-- Performance

CREATE OR REPLACE PROCEDURE database_create_indexes ()
LANGUAGE SQL
AS $BODY$
    CREATE INDEX texts_provenience_id_ix ON @extschema@.texts(provenience_id);
    CREATE INDEX texts_period_id_ix ON @extschema@.texts(period_id);
    CREATE INDEX texts_genre_id_ix ON @extschema@.texts(genre_id);
    CREATE INDEX texts_object_id_ix ON @extschema@.texts(object_id);
$BODY$;

CREATE OR REPLACE PROCEDURE database_drop_indexes ()
LANGUAGE SQL
AS $BODY$
    DROP INDEX @extschema@.texts_provenience_id_ix;
    DROP INDEX @extschema@.texts_period_id_ix;
    DROP INDEX @extschema@.texts_genre_id_ix;
    DROP INDEX @extschema@.texts_object_id_ix;
$BODY$;

CALL database_create_indexes ();


SELECT pg_catalog.pg_extension_config_dump('@extschema@.corpora', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.ensembles', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.texts', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.transliterations', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.compositions', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.sections', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.compounds', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.words', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.surfaces', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.blocks', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.lines', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.corpus', '');