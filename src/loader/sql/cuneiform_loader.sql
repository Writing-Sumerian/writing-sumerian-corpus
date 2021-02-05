
-- corpus

CREATE OR REPLACE FUNCTION load_corpus (path text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE
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
    transliteration_identifier text
);

CREATE TEMPORARY TABLE transliterations_tmp_ (
    identifier text,
    transliteration_identifier text,
    description text
);

EXECUTE format('COPY transliterations_tmp_ FROM %L CSV NULL ''\N''', path || 'transliterations.csv');

INSERT INTO transliteration_ids_tmp_ (transliteration_identifier)
SELECT
    transliteration_identifier
FROM transliterations_tmp_;

ALTER TABLE transliteration_ids_tmp_ ADD PRIMARY KEY (transliteration_identifier);

INSERT INTO transliterations (text_id, transliteration_id, description)
SELECT
    text_id, 
    transliteration_id, 
    description
FROM
    transliterations_tmp_
    JOIN text_ids_tmp_ USING (identifier)
    JOIN transliteration_ids_tmp_ USING (transliteration_identifier);

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
    compound_no integer,
    pn_type pn_type,
    language language,
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
    JOIN transliteration_ids_tmp_ USING (transliteration_identifier);

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
    word_no integer,
    compound_no integer,
    capitalized boolean
);

EXECUTE format('COPY words_tmp_ FROM %L CSV  NULL ''\N''', path || 'words.csv');

INSERT INTO public.words 
SELECT
    transliteration_id,
    word_no,
    compound_no,
    capitalized
FROM
    words_tmp_
    JOIN transliteration_ids_tmp_ USING (transliteration_identifier);

DROP TABLE words_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'words'
);

REINDEX TABLE words;


-- lines

CREATE TEMPORARY TABLE lines_tmp_ (
    transliteration_identifier text,
    line_no integer,
    part text,
    col text,
    line text,
    comment text
);

EXECUTE format('COPY lines_tmp_ FROM %L CSV  NULL ''\N''', path || 'lines.csv');

INSERT INTO public.lines 
SELECT
    transliteration_id,
    line_no,
    part,
    col,
    line,
    comment
FROM
    lines_tmp_
    JOIN transliteration_ids_tmp_ USING (transliteration_identifier);

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
        sign_no integer NOT NULL,
        line_no integer NOT NULL,
        word_no integer NOT NULL,
        value text,
        type SIGN_TYPE,
        indicator boolean,
        alignment ALIGNMENT,
        phonographic boolean,
        condition sign_condition,
        stem boolean,
        crits text,
        comment text,
        newline boolean,
        inverted boolean
);

EXECUTE format('COPY corpus_tmp_ FROM %L CSV NULL ''\N''', path || 'corpus.csv');

UPDATE corpus_tmp_ SET value = lower(value) WHERE type = 'value';

INSERT INTO corpus_norm
SELECT
    transliteration_id,
    sign_no,
    line_no,
    word_no,
    corpus_tmp_.value,
    value_id,
    sign_id,
    (type, indicator,  alignment, corpus_tmp_.phonographic)::sign_properties,
    stem,
    condition,
    crits,
    comment,
    newline,
    inverted
FROM
    corpus_tmp_
    JOIN transliteration_ids_tmp_ USING (transliteration_identifier)
    LEFT JOIN value_variants ON NOT corpus_tmp_.value ~ 'x' AND value_variants.value = corpus_tmp_.value
    LEFT JOIN values USING (value_id);

-- simple unread signs
UPDATE corpus_norm 
SET 
    sign_id = values.sign_id 
FROM 
    value_variants 
    JOIN values USING (value_id) 
WHERE corpus_norm.sign_id IS NULL AND (properties).type = 'sign' AND lower(orig_value) = value_variants.value;


-- unknown signs
UPDATE corpus_norm 
SET 
    sign_id = unknown_signs.sign_id 
FROM 
    unknown_signs
WHERE corpus_norm.sign_id IS NULL AND (properties).type = 'sign' AND orig_value = unknown_signs.name;


-- complex unread signs
WITH s AS (
SELECT
    transliteration_id,
    sign_no,
    string_agg(op||COALESCE(sign, ''), '' ORDER BY ord) AS normalized_sign
FROM
    corpus_norm
    LEFT JOIN LATERAL unnest(regexp_split_to_array(orig_value, '[.+()×%&@gštnkzi]+'), regexp_split_to_array(replace(orig_value, '+', '.'), '[^.+()×%&@gštnkzi]+')) WITH ORDINALITY as a(component, op, ord) ON TRUE
    LEFT JOIN value_variants ON lower(component) = value_variants.value
    LEFT JOIN values ON value_variants.value_id = values.value_id
    LEFT JOIN signs ON values.sign_id = signs.sign_id
WHERE corpus_norm.sign_id IS NULL AND (properties).type = 'sign'
GROUP BY 
    transliteration_id,
    sign_no
)
UPDATE corpus_norm 
SET 
    sign_id = signs.sign_id 
FROM
    s,
    signs
WHERE 
    normalized_sign = replace(sign, '+', '.') AND
    corpus_norm.transliteration_id = s.transliteration_id AND 
    corpus_norm.sign_no = s.sign_no;


-- x values of unknown signs
WITH 
s AS (
SELECT 
    transliteration_id,
    sign_no,
    unknown_signs.sign_id
FROM 
    corpus_norm
    JOIN words USING (transliteration_id, word_no)
    JOIN compounds USING (transliteration_id, compound_no)
    JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN LATERAL regexp_split_to_table(COALESCE(comment, compound_comment, line_comment), '[$;]') AS _(candidate) ON TRUE
    LEFT JOIN LATERAL trim(from replace(replace(regexp_replace(candidate, '[\|?!\[\]⌈⌉<>/\\\*]|^=|^:', '', 'g'), 'x', '×'), '@s', '@š')) AS __(candidate_cleaned) ON TRUE
    JOIN unknown_signs ON candidate_cleaned = unknown_signs.name
WHERE corpus_norm.sign_id IS NULL AND orig_value ~ 'x'
)
UPDATE corpus_norm 
SET 
    value_id = values.value_id,
    sign_id = signs.sign_id
FROM
    s, 
    signs, 
    values, 
    value_variants
WHERE
    s.sign_id = signs.sign_id AND
    signs.sign_id = values.sign_id AND
    value_variants.value_id = values.value_id AND
    value = orig_value AND
    corpus_norm.transliteration_id = s.transliteration_id AND 
    corpus_norm.sign_no = s.sign_no;


-- x values
WITH 
s AS (
SELECT 
    transliteration_id,
    sign_no,
    string_agg(op||COALESCE(sign, ''), '' ORDER BY ord) AS normalized_sign
FROM 
    corpus_norm
    JOIN words USING (transliteration_id, word_no)
    JOIN compounds USING (transliteration_id, compound_no)
    JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN LATERAL regexp_split_to_table(COALESCE(comment, '')||';'||COALESCE(compound_comment, '')||';'||COALESCE(line_comment, ''), '[$;]') AS _(candidate) ON TRUE
    LEFT JOIN LATERAL trim(from replace(replace(regexp_replace(candidate, '[\|?!\[\]⌈⌉<>/\\\*]|^=|^:', '', 'g'), 'x', '×'), '@s', '@š')) AS __(candidate_cleaned) ON TRUE
    LEFT JOIN LATERAL unnest(regexp_split_to_array(candidate_cleaned, '[.+()×%&@gštnkzi]+'), regexp_split_to_array(replace(candidate_cleaned, '+', '.'), '[^.+()×%&@gštnkzi]+')) WITH ORDINALITY as a(component, op, ord) ON TRUE
    LEFT JOIN value_variants ON lower(component) = value_variants.value
    LEFT JOIN values ON value_variants.value_id = values.value_id
    LEFT JOIN signs ON values.sign_id = signs.sign_id
WHERE corpus_norm.sign_id IS NULL AND orig_value ~ 'x'
GROUP BY 
    transliteration_id,
    sign_no,
    candidate
)
UPDATE corpus_norm 
SET 
    value_id = values.value_id,
    sign_id = signs.sign_id
FROM
    s, 
    signs, 
    values, 
    value_variants
WHERE
    normalized_sign = replace(sign, '+', '.') AND
    signs.sign_id = values.sign_id AND
    value_variants.value_id = values.value_id AND
    value = orig_value AND
    corpus_norm.transliteration_id = s.transliteration_id AND 
    corpus_norm.sign_no = s.sign_no;

DROP TABLE corpus_tmp_;

DROP TABLE transliteration_ids_tmp_;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'corpus_norm'
);

REINDEX TABLE corpus_norm;


REFRESH MATERIALIZED VIEW corpus_composition;

UPDATE pg_index
SET indisready = TRUE
WHERE indrelid IN (
    SELECT oid
    FROM pg_class
    WHERE relname = 'corpus_composition'
);

REINDEX TABLE corpus_composition;

SET CONSTRAINTS ALL IMMEDIATE;

END

$BODY$;


CREATE OR REPLACE FUNCTION reload_corpus (path text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE
    AS $BODY$
    
BEGIN

SET CONSTRAINTS All DEFERRED;

DELETE FROM corpus_norm;

DELETE FROM words;

DELETE FROM compounds;

DELETE FROM lines;

DELETE FROM transliterations;

DELETE FROM texts_norm;

PERFORM load_corpus(path);

END

$BODY$;



-- context

CREATE OR REPLACE FUNCTION load_context (path text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE
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


CREATE OR REPLACE FUNCTION reload_context (path text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

CREATE TEMPORARY TABLE periods_old_ AS SELECT * FROM periods;
CREATE TEMPORARY TABLE proveniences_old_ AS SELECT * FROM proveniences;
CREATE TEMPORARY TABLE genres_old_ AS SELECT * FROM genres;

DELETE FROM periods;
DELETE FROM proveniences;
DELETE FROM genres;

PERFORM load_context(path);

UPDATE texts_norm SET period_id = (SELECT periods.period_id FROM periods JOIN periods_old_ USING (name) WHERE periods_old_.period_id = texts_norm.period_id);
UPDATE texts_norm SET provenience_id = (SELECT proveniences.provenience_id FROM proveniences JOIN proveniences_old_ USING (name) WHERE proveniences_old_.provenience_id = texts_norm.provenience_id);
UPDATE texts_norm SET genre_id = (SELECT genres.genre_id FROM genres JOIN genres_old_ USING (name) WHERE genres_old_.genre_id = texts_norm.genre_id);

DROP TABLE periods_old_;
DROP TABLE proveniences_old_;
DROP TABLE genres_old_;

END

$BODY$;


-- signlist

CREATE OR REPLACE FUNCTION load_signlist (path text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

CREATE TEMPORARY TABLE values_tmp_ (
    sign_name text,
    main_value text,
    phonographic boolean
);

CREATE TEMPORARY TABLE value_ids_tmp_ (
    value_id integer DEFAULT nextval('values_value_id_seq'),
    sign_name text,
    main_value text
);

CREATE TEMPORARY TABLE value_variants_tmp_ (
    sign_name text,
    main_value text,
    value text
);

CREATE TEMPORARY TABLE unknown_signs_tmp_ (
    name text,
    sign_name text
);

EXECUTE format('COPY signs(sign, composition, unicode, mzl_no) FROM %L CSV NULL ''\N''', path || 'signs.csv');
EXECUTE format('COPY values_tmp_ FROM %L CSV NULL ''\N''', path || 'values.csv');
EXECUTE format('COPY value_variants_tmp_ FROM %L CSV NULL ''\N''', path || 'value_variants.csv');
EXECUTE format('COPY unknown_signs_tmp_ FROM %L CSV NULL ''\N''', path || 'unknown_signs.csv');

INSERT INTO value_ids_tmp_(sign_name, main_value)
SELECT
    sign_name,
    main_value
FROM values_tmp_;

INSERT INTO value_variants(value_id, value)
SELECT
    value_id,
    value
FROM
    value_variants_tmp_ a
    JOIN value_ids_tmp_ USING (sign_name, main_value);

INSERT INTO values
SELECT
    value_ids_tmp_.value_id,
    sign_id,
    value_variant_id,
    phonographic
FROM
    values_tmp_
    JOIN value_ids_tmp_ USING (sign_name, main_value)
    JOIN signs ON sign_name = sign
    JOIN value_variants ON value = main_value AND value_variants.value_id = value_ids_tmp_.value_id;

INSERT INTO unknown_signs(name, sign_id)
SELECT
    unknown_signs_tmp_.name,
    sign_id
FROM
    unknown_signs_tmp_
    JOIN signs ON sign_name = sign;

DROP TABLE values_tmp_;
DROP TABLE value_ids_tmp_;
DROP TABLE value_variants_tmp_;
DROP TABLE unknown_signs_tmp_;

REFRESH MATERIALIZED VIEW sign_composition;
REFRESH MATERIALIZED VIEW sign_identifiers;

END

$BODY$;


CREATE OR REPLACE FUNCTION reload_signlist (path text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

DELETE FROM unknown_signs;
DELETE FROM value_variants;
DELETE FROM values;
DELETE FROM signs;

PERFORM load_signlist(path);

END

$BODY$;
