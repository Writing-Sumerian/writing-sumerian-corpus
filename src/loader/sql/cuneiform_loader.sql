
-- corpus

CREATE TABLE corpus_unencoded (
    transliteration_id integer,
    sign_no integer,
    value text,
    sign_spec text,
    type sign_type NOT NULL,
    PRIMARY KEY (transliteration_id, sign_no)
);

CREATE INDEX ON corpus_unencoded (type, (sign_spec IS null));

CALL create_corpus_encoder('corpus_encoder', 'corpus_unencoded', '{transliteration_id}');


CREATE OR REPLACE PROCEDURE load_corpus (path text)
    LANGUAGE PLPGSQL
    AS $BODY$
    
BEGIN

CALL database_drop_indexes ();


-- corpora

CREATE TEMPORARY TABLE corpora_tmp_ (
    name_short text,
    name_long text,
    core boolean
)
ON COMMIT DROP;

EXECUTE format('COPY corpora_tmp_ FROM %L CSV NULL ''\N''', path || 'corpora.csv');

INSERT INTO corpora (name_short, name_long, core)
SELECT
    name_short,
    name_long,
    core
FROM
    corpora_tmp_;


-- texts

CREATE TEMPORARY TABLE text_ids_tmp_ (
    text_id integer DEFAULT nextval('texts_norm_text_id_seq'),
    identifier text
)
ON COMMIT DROP;

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
)
ON COMMIT DROP;

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


-- transliterations

CREATE TEMPORARY TABLE transliteration_ids_tmp_ (
    transliteration_id integer DEFAULT nextval('transliterations_transliteration_id_seq'),
    transliteration_identifier text UNIQUE
)
ON COMMIT DROP;

CREATE TEMPORARY TABLE transliterations_tmp_ (
    identifier text,
    transliteration_identifier text,
    corpus_identifier text
)
ON COMMIT DROP ;

EXECUTE format('COPY transliterations_tmp_ FROM %L CSV NULL ''\N''', path || 'transliterations.csv');

INSERT INTO transliteration_ids_tmp_ (transliteration_identifier)
SELECT
    transliteration_identifier
FROM transliterations_tmp_;

ALTER TABLE transliteration_ids_tmp_ ADD PRIMARY KEY (transliteration_identifier);

INSERT INTO transliterations (text_id, transliteration_id, corpus_id)
SELECT
    text_id, 
    transliteration_id, 
    corpus_id
FROM
    transliterations_tmp_
    JOIN text_ids_tmp_ USING (identifier)
    JOIN transliteration_ids_tmp_ USING (transliteration_identifier)
    JOIN corpora ON corpus_identifier = name_short;


-- sections

CREATE TEMPORARY TABLE sections_tmp_ (
    transliteration_identifier text,
    section_no integer,
    section_name text,
    composition_name text,
    witness_type witness_type
)
ON COMMIT DROP;

EXECUTE format('COPY sections_tmp_ FROM %L CSV NULL ''\N''', path || 'sections.csv');

INSERT INTO compositions (composition_name) SELECT DISTINCT composition_name FROM sections_tmp_ ON CONFLICT DO NOTHING;

INSERT INTO sections
SELECT
    transliteration_id,
    section_no,
    section_name,
    composition_id,
    witness_type
FROM
    sections_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier)
    LEFT JOIN compositions USING (composition_name);


-- compounds

CREATE TEMPORARY TABLE compounds_tmp_ (
    transliteration_identifier text,
    compound_no integer,
    pn_type pn_type,
    language language,
    section_no integer,
    comment text
)
ON COMMIT DROP;

EXECUTE format('COPY compounds_tmp_ FROM %L CSV NULL ''\N''', path || 'compounds.csv');

INSERT INTO compounds 
SELECT
    transliteration_id,
    compound_no,
    pn_type,
    language,
    section_no,
    comment
FROM
    compounds_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier);


-- words

CREATE TEMPORARY TABLE words_tmp_ (
    transliteration_identifier text,
    word_no integer,
    compound_no integer,
    capitalized boolean
)
ON COMMIT DROP ;

EXECUTE format('COPY words_tmp_ FROM %L CSV  NULL ''\N''', path || 'words.csv');

INSERT INTO words 
SELECT
    transliteration_id,
    word_no,
    compound_no,
    capitalized
FROM
    words_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier);


-- objects

CREATE TEMPORARY TABLE objects_tmp_ (
    transliteration_identifier text,
    object_no integer,
    object object_type,
    object_data text,
    object_comment text
)
ON COMMIT DROP;

EXECUTE format('COPY objects_tmp_ FROM %L CSV  NULL ''\N''', path || 'objects.csv');

INSERT INTO objects 
SELECT
    transliteration_id,
    object_no,
    object,
    object_data,
    object_comment
FROM
    objects_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier);


-- surfaces

CREATE TEMPORARY TABLE surfaces_tmp_ (
    transliteration_identifier text,
    surface_no integer,
    object_no integer,
    surface_type surface_type,
    surface_data text,
    surface_comment text
)
ON COMMIT DROP;

EXECUTE format('COPY surfaces_tmp_ FROM %L CSV  NULL ''\N''', path || 'surfaces.csv');

INSERT INTO surfaces 
SELECT
    transliteration_id,
    surface_no,
    object_no,
    surface_type,
    surface_data,
    surface_comment
FROM
    surfaces_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier);


-- blocks

CREATE TEMPORARY TABLE blocks_tmp_ (
    transliteration_identifier text,
    block_no integer,
    surface_no integer,
    block_type block_type,
    block_data text,
    block_comment text
)
ON COMMIT DROP;

EXECUTE format('COPY blocks_tmp_ FROM %L CSV  NULL ''\N''', path || 'blocks.csv');

INSERT INTO blocks 
SELECT
    transliteration_id,
    block_no,
    surface_no,
    block_type,
    block_data,
    block_comment
FROM
    blocks_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier);


-- lines

CREATE TEMPORARY TABLE lines_tmp_ (
    transliteration_identifier text,
    line_no integer,
    block_no integer,
    line text,
    comment text,
    UNIQUE (transliteration_identifier, line_no)
)
ON COMMIT DROP;

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
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier);


-- corpus

CREATE TEMPORARY TABLE corpus_tmp_ (
    transliteration_identifier text,
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
)
ON COMMIT DROP;

EXECUTE format('COPY corpus_tmp_ FROM %L CSV NULL ''\N''', path || 'corpus.csv');

INSERT INTO corpus
SELECT
    transliteration_id,
    sign_no,
    line_no,
    word_no,
    null,
    null,
    CASE WHEN type = 'value' OR type = 'sign' THEN NULL ELSE corpus_tmp_.value END,
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
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier);

INSERT INTO corpus_unencoded
SELECT
    transliteration_id,
    sign_no,
    value,
    sign_spec,
    type
FROM
    corpus_tmp_
    LEFT JOIN transliteration_ids_tmp_ USING (transliteration_identifier)
WHERE
    type = 'value' OR
    type = 'sign';


CALL database_create_indexes ();

COMMIT;

CLUSTER corpus;

UPDATE corpus SET 
    value_id = corpus_encoder.value_id, 
    sign_variant_id = corpus_encoder.sign_variant_id
FROM
    corpus_encoder
WHERE
    corpus.transliteration_id = corpus_encoder.transliteration_id AND
    corpus.sign_no = corpus_encoder.sign_no;

DELETE FROM corpus_unencoded 
USING corpus 
WHERE 
    corpus.transliteration_id = corpus_unencoded.transliteration_id AND
    corpus.sign_no = corpus_unencoded.sign_no AND
    corpus.sign_variant_id IS NOT NULL;

UPDATE corpus SET 
    custom_value = corpus_unencoded.value || COALESCE('(' || corpus_unencoded.sign_spec || ')', '')
FROM
    corpus_unencoded
WHERE
    corpus.transliteration_id = corpus_unencoded.transliteration_id AND
    corpus.sign_no = corpus_unencoded.sign_no;

CLUSTER corpus;

END

$BODY$;


CREATE OR REPLACE PROCEDURE reload_corpus (path text)
    LANGUAGE PLPGSQL
    AS $BODY$
    
BEGIN

SET CONSTRAINTS All DEFERRED;

DELETE FROM corpus_unencoded;

DELETE FROM corpus;
DELETE FROM words;
DELETE FROM compounds;
DELETE FROM lines;
DELETE FROM blocks;
DELETE FROM surfaces;
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

EXECUTE format('COPY proveniences(cigs_id, name, modern_name, latitude, longitude) FROM %L CSV NULL ''\N''', path || 'proveniences.csv');

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

CALL signlist_refresh();

END

$BODY$;


CREATE OR REPLACE PROCEDURE reload_signlist (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

DELETE FROM glyph_synonyms;
DELETE FROM glyph_values;
DELETE FROM value_variants;
DELETE FROM values;
DELETE FROM allographs;
DELETE FROM allomorph_components;
DELETE FROM allomorphs;
DELETE FROM graphemes;
DELETE FROM glyphs;
DELETE FROM signs;

CALL load_signlist(path);

END

$BODY$;
