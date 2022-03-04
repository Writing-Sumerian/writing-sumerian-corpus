
-- corpus

CREATE OR REPLACE PROCEDURE load_corpus (path text)
    LANGUAGE PLPGSQL
    AS $BODY$
    
BEGIN

-- disable all indices
UPDATE pg_index
SET indisready = FALSE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname IN ('texts_norm', 'transliterations', 'lines', 'compounds', 'words', 'corpus_norm', 'corpus_composition')
);

SET CONSTRAINTS All DEFERRED;


-- texts

CREATE TEMPORARY TABLE text_ids_tmp_ (
    text_id integer DEFAULT nextval('texts_norm_text_id_seq'),
    identifier text
);

CREATE TEMPORARY TABLE texts_tmp_ (
    identifier text,
    cdli_no text,
    bdtns_no text,
    citation text,
    provenience text,
    provenience_comment text,
    period text,
    period_comment text,
    genre text,
    genre_comment text,
    date text,
    archive text
);

EXECUTE format('COPY texts_tmp_ FROM %L CSV NULL ''\N''', path || 'texts.csv');

INSERT INTO text_ids_tmp_ (identifier)
SELECT
    identifier
FROM texts_tmp_;

ALTER TABLE text_ids_tmp_ ADD PRIMARY KEY (identifier);

INSERT INTO texts_norm (text_id, cdli_no, bdtns_no, citation, provenience_id, provenience_comment, period_id, period_comment, genre_id, genre_comment, date, archive)
SELECT
    text_id,
    cdli_no,
    bdtns_no,
    citation,
    provenience_id,
    COALESCE(provenience_comment, ''),
    period_id,
    COALESCE(period_comment, ''),
    genre_id,
    COALESCE(genre_comment, ''),
    NULL, --TABLEDATE (king, y, m, d),
    archive
FROM
    texts_tmp_
    JOIN text_ids_tmp_ USING (identifier)
    LEFT JOIN periods ON (period = periods.name)
    LEFT JOIN proveniences ON (provenience = proveniences.name)
    LEFT JOIN genres ON (genre = genres.name);

DROP TABLE texts_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'texts_norm'
);

REINDEX TABLE texts_norm;


-- transliterations

CREATE TEMPORARY TABLE transliteration_ids_tmp_ (
    transliteration_id integer DEFAULT nextval('transliterations_transliteration_id_seq'),
    transliteration_identifier text,
    object text,
    UNIQUE (transliteration_identifier, object)
);

CREATE TEMPORARY TABLE transliterations_tmp_ (
    identifier text,
    transliteration_identifier text,
    object text,
    description text
);

EXECUTE format('COPY transliterations_tmp_ FROM %L CSV NULL ''\N''', path || 'transliterations.csv');

INSERT INTO transliteration_ids_tmp_ (transliteration_identifier, object)
SELECT
    transliteration_identifier,
    object
FROM transliterations_tmp_;

ALTER TABLE transliteration_ids_tmp_ ADD PRIMARY KEY (transliteration_identifier, object);

INSERT INTO transliterations (text_id, transliteration_id, object, description)
SELECT
    text_id, 
    transliteration_id, 
    object,
    description
FROM
    transliterations_tmp_
    JOIN text_ids_tmp_ USING (identifier)
    JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object);

DROP TABLE transliterations_tmp_;

DROP TABLE text_ids_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'transliterations'
);

REINDEX TABLE transliterations;


-- compounds

CREATE TEMPORARY TABLE compounds_tmp_ (
    transliteration_identifier text,
    object text,
    compound_no integer,
    pn_type pn_type,
    language language,
    section text,
    comment text
);

EXECUTE format('COPY compounds_tmp_ FROM %L CSV NULL ''\N''', path || 'compounds.csv');

INSERT INTO compounds 
SELECT
    transliteration_id,
    compound_no,
    pn_type,
    language,
    comment
FROM
    compounds_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object);

DROP TABLE compounds_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'compounds'
);

REINDEX TABLE compounds;


-- words

CREATE TEMPORARY TABLE words_tmp_ (
    transliteration_identifier text,
    object text,
    word_no integer,
    compound_no integer,
    capitalized boolean
);

EXECUTE format('COPY words_tmp_ FROM %L CSV  NULL ''\N''', path || 'words.csv');

INSERT INTO words 
SELECT
    transliteration_id,
    word_no,
    compound_no,
    capitalized
FROM
    words_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object);

DROP TABLE words_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'words'
);

REINDEX TABLE words;


-- surfaces

CREATE TEMPORARY TABLE surfaces_tmp_ (
    transliteration_identifier text,
    object text,
    surface_no integer,
    surface_type surface_type,
    surface_data text,
    surface_comment text
);

EXECUTE format('COPY surfaces_tmp_ FROM %L CSV  NULL ''\N''', path || 'surfaces.csv');

INSERT INTO surfaces 
SELECT
    transliteration_id,
    surface_no,
    surface_type,
    surface_data,
    surface_comment
FROM
    surfaces_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object);

DROP TABLE surfaces_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'surfaces'
);

REINDEX TABLE surfaces;

-- blocks

CREATE TEMPORARY TABLE blocks_tmp_ (
    transliteration_identifier text,
    object text,
    block_no integer,
    surface_no integer,
    block_type block_type,
    block_data text,
    block_comment text
);

EXECUTE format('COPY blocks_tmp_ FROM %L CSV  NULL ''\N''', path || 'blocks.csv');

INSERT INTO blocks 
SELECT
    transliteration_id,
    block_no,
    block_type,
    block_data,
    block_comment,
    surface_no
FROM
    blocks_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object);

DROP TABLE blocks_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'blocks'
);

REINDEX TABLE blocks;


-- lines

CREATE TEMPORARY TABLE lines_tmp_ (
    transliteration_identifier text,
    object text,
    line_no integer,
    block_no integer,
    line text,
    comment text,
    UNIQUE (transliteration_identifier, object, line_no)
);

EXECUTE format('COPY lines_tmp_ FROM %L CSV  NULL ''\N''', path || 'lines.csv');

INSERT INTO lines 
SELECT
    transliteration_id,
    line_no,
    block_no,
    line,
    comment
FROM
    lines_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object);

DROP TABLE lines_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'lines'
);

REINDEX TABLE lines;


-- corpus

CREATE TEMPORARY TABLE corpus_tmp_ (
        transliteration_identifier text,
        object text,
        sign_no integer NOT NULL,
        line_no integer NOT NULL,
        word_no integer NOT NULL,
        value text,
        sign_spec text,
        type SIGN_TYPE,
        indicator boolean,
        alignment ALIGNMENT,
        phonographic boolean,
        condition sign_condition,
        stem boolean,
        crits text,
        comment text,
        newline boolean,
        inverted boolean,
        ligature boolean
);

EXECUTE format('COPY corpus_tmp_ FROM %L CSV NULL ''\N''', path || 'corpus.csv');

CREATE INDEX ON corpus_tmp_ (type, (sign_spec IS null));

CREATE TEMPORARY VIEW normalized_signs AS
WITH x AS (
    SELECT
        transliteration_identifier,
        object,
        sign_no,
        glyph_no,
        normalize_operators(string_agg(op||COALESCE('('||sign||')', ''), '' ORDER BY component_no)) AS normalized_glyph
    FROM
        corpus_tmp_
        LEFT JOIN LATERAL split_glyphs(COALESCE(sign_spec, value, '')) WITH ORDINALITY AS a(glyph, glyph_no) ON TRUE
        LEFT JOIN LATERAL split_sign(glyph) WITH ORDINALITY AS b(component, op, component_no) ON TRUE
        LEFT JOIN sign_map ON component = identifier
    WHERE sign_spec IS NOT NULL OR type = 'sign'
    GROUP BY 
        transliteration_identifier,
        object,
        sign_no,
        glyph_no
)
SELECT 
    transliteration_identifier,
    object,
    sign_no,
    string_agg(normalized_glyph, '.' ORDER BY glyph_no) AS normalized_sign
FROM
    x
GROUP BY
    transliteration_identifier,
    object,
    sign_no;


-- values
WITH value_map AS (
    SELECT
        value,
        value_id,
        sign_variant_id
    FROM
        value_variants
        JOIN values USING (value_id)
        JOIN allomorphs USING (sign_id)
        JOIN sign_variants USING (allomorph_id)
    WHERE value !~ 'x' AND sign_variants.variant_type = 'default'
    UNION ALL
    SELECT
        value,
        value_id,
        sign_variant_id
    FROM
        glyph_values 
        JOIN sign_variants USING (glyph_ids)
        JOIN allomorphs USING (allomorph_id)
        JOIN values USING (sign_id, value_id)
        JOIN sign_variants_text USING (sign_variant_id)
    WHERE sign_variants.specific
)
INSERT INTO corpus_norm
SELECT
    transliteration_id,
    sign_no,
    line_no,
    word_no,
    corpus_tmp_.value,
    value_id,
    sign_variant_id,
    null,
    (type, indicator,  alignment, corpus_tmp_.phonographic)::sign_properties,
    stem,
    condition,
    crits,
    comment,
    newline,
    inverted,
    ligature
FROM
    corpus_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object)
    LEFT JOIN value_map USING (value)
WHERE sign_spec IS NULL AND type != 'sign' AND type != 'number';

-- values with sign_spec
WITH value_map AS (
    SELECT
        value,
        value_id,
        sign_variant_id,
        glyphs
    FROM
        value_variants
        JOIN values USING (value_id)
        JOIN allomorphs USING (sign_id)
        JOIN sign_variants_text USING (allomorph_id)
    UNION ALL
    SELECT
        value,
        value_id,
        sign_variant_id,
        glyphs
    FROM
        glyph_values 
        JOIN sign_variants USING (glyph_ids)
        JOIN allomorphs USING (allomorph_id)
        JOIN values USING (sign_id, value_id)
        JOIN sign_variants_text USING (sign_variant_id)
)
INSERT INTO corpus_norm
SELECT DISTINCT
    transliteration_id,
    sign_no,
    line_no,
    word_no,
    corpus_tmp_.value || COALESCE('(' || sign_spec  || ')', ''),
    value_map.value_id,
    value_map.sign_variant_id,
    null,
    (type, indicator,  alignment, corpus_tmp_.phonographic)::sign_properties,
    stem,
    condition,
    crits,
    comment,
    newline,
    inverted,
    ligature
FROM
    corpus_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object)
    LEFT JOIN normalized_signs USING (transliteration_identifier, object, sign_no)
    LEFT JOIN value_map ON glyphs = normalized_sign AND 
        ((corpus_tmp_.value !~ 'x' AND corpus_tmp_.value = value_map.value) OR  
         (corpus_tmp_.value ~ 'x' AND replace(corpus_tmp_.value, 'x', '') = regexp_replace(value_map.value, '[x0-9]+', '')))
WHERE sign_spec IS NOT NULL AND type != 'sign' AND type != 'number';

-- signs
INSERT INTO corpus_norm
SELECT
    transliteration_id,
    sign_no,
    line_no,
    word_no,
    corpus_tmp_.value,
    null,
    sign_variant_id,
    null,
    (type, indicator,  alignment, corpus_tmp_.phonographic)::sign_properties,
    stem,
    condition,
    crits,
    comment,
    newline,
    inverted,
    ligature
FROM
    corpus_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object)
    LEFT JOIN normalized_signs USING (transliteration_identifier, object, sign_no)
    LEFT JOIN sign_variants_text ON glyphs = normalized_sign AND specific AND length = 1
WHERE type = 'sign';

-- numbers
INSERT INTO corpus_norm
SELECT
    transliteration_id,
    sign_no,
    line_no,
    word_no,
    corpus_tmp_.value || COALESCE('(' || sign_spec  || ')', ''),
    null,
    sign_variant_id,
    corpus_tmp_.value,
    (type, indicator,  alignment, corpus_tmp_.phonographic)::sign_properties,
    stem,
    condition,
    crits,
    comment,
    newline,
    inverted,
    ligature
FROM
    corpus_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier, object)
    LEFT JOIN normalized_signs USING (transliteration_identifier, object, sign_no)
    LEFT JOIN grapheme_identifiers ON normalized_sign = grapheme_identifier
    LEFT JOIN sign_variants ON grapheme_ids = ARRAY[grapheme_id] AND specific
    WHERE type = 'number';

DROP TABLE corpus_tmp_ CASCADE;

DROP TABLE transliteration_ids_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'corpus_norm'
);

REINDEX TABLE corpus_norm;

SET CONSTRAINTS ALL IMMEDIATE;

CLUSTER corpus_norm;

END

$BODY$;


CREATE OR REPLACE PROCEDURE reload_corpus (path text)
    LANGUAGE PLPGSQL
    AS $BODY$
    
BEGIN

SET CONSTRAINTS All DEFERRED;

DELETE FROM corpus_norm;

DELETE FROM words;

DELETE FROM compounds;

DELETE FROM lines;

DELETE FROM transliterations;

DELETE FROM texts_norm;

CALL load_corpus(path);

END

$BODY$;



-- context

CREATE OR REPLACE PROCEDURE load_context (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

CREATE TEMPORARY TABLE periods_tmp_ (
    period_id integer DEFAULT nextval('periods_period_id_seq'),
    name text,
    start_year integer,
    end_year integer,
    super_name text
);

EXECUTE format('COPY periods_tmp_(name, start_year, end_year, super_name) FROM %L CSV NULL ''\N''', path || 'periods.csv');

INSERT INTO periods
SELECT
    a.period_id,
    a.name,
    int4range(a.end_year, a.start_year),
    super.period_id
FROM
    periods_tmp_ a
    LEFT JOIN periods_tmp_ super ON a.super_name = super.name;

DROP TABLE periods_tmp_;

EXECUTE format('COPY proveniences(name, modern_name, latitude, longitude) FROM %L CSV NULL ''\N''', path || 'proveniences.csv');

EXECUTE format('COPY genres(name) FROM %L CSV NULL ''\N''', path || 'genres.csv');

END

$BODY$;


CREATE OR REPLACE PROCEDURE reload_context (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

CREATE TEMPORARY TABLE periods_old_ AS SELECT * FROM periods;
CREATE TEMPORARY TABLE proveniences_old_ AS SELECT * FROM proveniences;
CREATE TEMPORARY TABLE genres_old_ AS SELECT * FROM genres;

DELETE FROM periods;
DELETE FROM proveniences;
DELETE FROM genres;

CALL load_context(path);

UPDATE texts_norm SET period_id = (SELECT periods.period_id FROM periods JOIN periods_old_ USING (name) WHERE periods_old_.period_id = texts_norm.period_id);
UPDATE texts_norm SET provenience_id = (SELECT proveniences.provenience_id FROM proveniences JOIN proveniences_old_ USING (name) WHERE proveniences_old_.provenience_id = texts_norm.provenience_id);
UPDATE texts_norm SET genre_id = (SELECT genres.genre_id FROM genres JOIN genres_old_ USING (name) WHERE genres_old_.genre_id = texts_norm.genre_id);

DROP TABLE periods_old_;
DROP TABLE proveniences_old_;
DROP TABLE genres_old_;

END

$BODY$;


-- signlist

CREATE OR REPLACE PROCEDURE load_signlist (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format('COPY glyphs(glyph_id, glyph, unicode) FROM %L CSV NULL ''\N''', path || 'glyphs.csv');
EXECUTE format('COPY glyph_synonyms(synonym, glyph_id) FROM %L CSV NULL ''\N''', path || 'glyph_synonyms.csv');
EXECUTE format('COPY glyph_values(value, value_id, glyph_ids) FROM %L CSV NULL ''\N''', path || 'glyph_values.csv');
EXECUTE format('COPY graphemes(grapheme_id, grapheme, mzl_no) FROM %L CSV NULL ''\N''', path || 'graphemes.csv');
EXECUTE format('COPY allographs(grapheme_id, glyph_id, variant_type, specific) FROM %L CSV NULL ''\N''', path || 'allographs.csv');
EXECUTE format('COPY allomorphs(allomorph_id, sign_id, variant_type, specific) FROM %L CSV NULL ''\N''', path || 'allomorphs.csv');
EXECUTE format('COPY allomorph_components(allomorph_id, pos, grapheme_id) FROM %L CSV NULL ''\N''', path || 'allomorph_components.csv');
EXECUTE format('COPY value_variants(value_variant_id, value_id, value) FROM %L CSV NULL ''\N''', path || 'value_variants.csv');
EXECUTE format('COPY values(value_id, sign_id, main_variant_id, phonographic) FROM %L CSV NULL ''\N''', path || 'values.csv');

INSERT INTO signs SELECT DISTINCT sign_id FROM allomorphs;

PERFORM setval('glyphs_glyph_id_seq', max(glyph_id)) FROM glyphs;
PERFORM setval('graphemes_grapheme_id_seq', max(grapheme_id)) FROM graphemes;
PERFORM setval('allographs_allograph_id_seq', max(allograph_id)) FROM allographs;
PERFORM setval('allomorphs_allomorph_id_seq', max(allomorph_id)) FROM allomorphs;
PERFORM setval('values_value_id_seq', max(value_id)) FROM values;
PERFORM setval('value_variants_value_variant_id_seq', max(value_variant_id)) FROM value_variants;
PERFORM setval('signs_sign_id_seq', max(sign_id)) FROM signs;

CALL signlist_refresh_materialized_views();

END

$BODY$;


CREATE OR REPLACE PROCEDURE reload_signlist (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

DELETE FROM unknown_signs;
DELETE FROM value_variants;
DELETE FROM values;
DELETE FROM sign_variants;
DELETE FROM signs;

CALL load_signlist(path);

END

$BODY$;
