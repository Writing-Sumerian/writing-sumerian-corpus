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



CREATE TYPE witness_type AS ENUM (
    'original',
    'print',
    'copy',
    'variant'
);

CREATE TABLE compositions (
    composition_id SERIAL PRIMARY KEY,
    composition_name text UNIQUE NOT NULL,
    witness_type witness_type NOT NULL,
    parent_composition_id integer REFERENCES compositions (composition_id) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE VIEW compositions_flat AS 
WITH RECURSIVE t(composition_id, composition_id_2) AS (
    SELECT
        composition_id,
        composition_id
    FROM
        compositions
    UNION
    SELECT 
        t.composition_id,
        b.parent_composition_id
    FROM
        t
        JOIN compositions b ON t.composition_id_2 = b.composition_id
    WHERE
        b.parent_composition_id IS NOT NULL
)
SELECT * FROM t;


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
    composition_id integer REFERENCES compositions (composition_id) DEFERRABLE INITIALLY IMMEDIATE,
    FOREIGN KEY (object_id, object_subtype_id) REFERENCES object_subtypes (object_id, object_subtype_id)
);


CREATE TABLE transliterations (
    transliteration_id serial PRIMARY KEY,
    text_id integer NOT NULL REFERENCES texts (text_id) DEFERRABLE INITIALLY IMMEDIATE,
    corpus_id integer NOT NULL REFERENCES corpora (corpus_id) DEFERRABLE INITIALLY IMMEDIATE
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


CREATE OR REPLACE VIEW texts_compositions AS 
WITH x AS (
    SELECT 
        text_id,
        composition_id
    FROM
        texts
    WHERE
        composition_id IS NOT NULL
    UNION
    SELECT
        text_id, 
        composition_id
    FROM
        sections
        JOIN transliterations USING (transliteration_id)
    WHERE
        composition_id IS NOT NULL
)
SELECT
    text_id,
    composition_id_2 AS composition_id
FROM
    x
    JOIN compositions_flat USING (composition_id);


-- Performance

CREATE OR REPLACE PROCEDURE database_create_indexes ()
LANGUAGE SQL
AS $BODY$
    CREATE INDEX texts_provenience_id_ix ON @extschema@.texts(provenience_id);
    CREATE INDEX texts_period_id_ix ON @extschema@.texts(period_id);
    CREATE INDEX texts_genre_id_ix ON @extschema@.texts(genre_id);
    CREATE INDEX texts_object_id_ix ON @extschema@.texts(object_id);
    CREATE INDEX texts_composition_id_ix ON @extschema@.texts(composition_id);
    CREATE INDEX compositions_parent_composition_id_ix ON @extschema@.compositions(parent_composition_id);
    CREATE INDEX sections_composition_id_ix ON @extschema@.sections(composition_id);
$BODY$;

CREATE OR REPLACE PROCEDURE database_drop_indexes ()
LANGUAGE SQL
AS $BODY$
    DROP INDEX @extschema@.texts_provenience_id_ix;
    DROP INDEX @extschema@.texts_period_id_ix;
    DROP INDEX @extschema@.texts_genre_id_ix;
    DROP INDEX @extschema@.texts_object_id_ix;
    DROP INDEX @extschema@.texts_composition_id_ix;
    DROP INDEX @extschema@.compositions_parent_composition_id_ix;
    DROP INDEX @extschema@.sections_composition_id_ix;
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


CREATE OR REPLACE PROCEDURE public.load_corpus_(path text)
 LANGUAGE plpgsql
AS 
$BODY$

 BEGIN

 SET CONSTRAINTS ALL DEFERRED;

 EXECUTE format('COPY compositions FROM %L CSV NULL ''\N''', path || 'compositions.csv');
 EXECUTE format('COPY corpora FROM %L CSV NULL ''\N''', path || 'corpora.csv');
 EXECUTE format('COPY ensembles FROM %L CSV NULL ''\N''', path || 'ensembles.csv');
 EXECUTE format('COPY texts FROM %L CSV NULL ''\N''', path || 'texts.csv');
 EXECUTE format('COPY transliterations FROM %L CSV NULL ''\N''', path || 'transliterations.csv');         
 EXECUTE format('COPY surfaces FROM %L CSV NULL ''\N''', path || 'surfaces.csv');
 EXECUTE format('COPY blocks FROM %L CSV NULL ''\N''', path || 'blocks.csv');
 EXECUTE format('COPY lines FROM %L CSV NULL ''\N''', path || 'lines.csv');
 EXECUTE format('COPY sections FROM %L CSV NULL ''\N''', path || 'sections.csv');
 EXECUTE format('COPY compounds FROM %L CSV NULL ''\N''', path || 'compounds.csv');
 EXECUTE format('COPY words FROM %L CSV NULL ''\N''', path || 'words.csv');
 EXECUTE format('COPY corpus FROM %L CSV NULL ''\N''', path || 'corpus.csv');

 PERFORM setval('compositions_composition_id_seq', max(composition_id)) FROM compositions;
 PERFORM setval('corpora_corpus_id_seq', max(corpus_id)) FROM corpora;
 PERFORM setval('ensembles_ensemble_id_seq', max(ensemble_id)) FROM ensembles;
 PERFORM setval('texts_text_id_seq', max(text_id)) FROM texts;
 PERFORM setval('transliterations_transliteration_id_seq', max(transliteration_id)) FROM transliterations;

 END
 $BODY$;