CREATE TYPE cun_agg_stype AS (
    string text,
    sign_no integer,
    word_no integer,
    compound_no integer,
    line_no integer,
    TYPE sign_type,
    phonographic boolean,
    indicator boolean,
    alignment alignment,
    stem boolean,
    condition sign_condition,
    language language,
    unknown_reading boolean
);

CREATE OR REPLACE FUNCTION cun_agg_sfunc (
    cun_agg_stype, 
    text, 
    boolean, 
    integer, 
    integer, 
    integer, 
    integer, 
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    text, 
    text
    )
    RETURNS cun_agg_stype
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_sfunc'
    LANGUAGE C
    IMMUTABLE;

CREATE OR REPLACE FUNCTION cun_agg_finalfunc (state cun_agg_stype)
    RETURNS text
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_finalfunc'
    LANGUAGE C
    STRICT IMMUTABLE;

CREATE AGGREGATE cun_agg (
    text, 
    boolean, 
    integer, 
    integer, 
    integer, 
    integer, 
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    text, 
    text
    ) (
    SFUNC = cun_agg_sfunc,
    STYPE = cun_agg_stype,
    FINALFUNC = cun_agg_finalfunc,
    INITCOND = '("",0,0,0,0,value,false,false,center,false,intact,sumerian,FALSE)'
);

CREATE OR REPLACE FUNCTION cun_agg_html_sfunc (
    cun_agg_stype, 
    text, 
    boolean, 
    integer, 
    integer, 
    integer, 
    integer, 
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    text, 
    text
    )
    RETURNS cun_agg_stype
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_html_sfunc'
    LANGUAGE C
    IMMUTABLE;

CREATE OR REPLACE FUNCTION cun_agg_html_finalfunc (state cun_agg_stype)
    RETURNS text
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_html_finalfunc'
    LANGUAGE C
    STRICT IMMUTABLE;

CREATE AGGREGATE cun_agg_html (
    text, 
    boolean, 
    integer, 
    integer, 
    integer, 
    integer, 
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    text, 
    text
    ) (
    SFUNC = cun_agg_html_sfunc,
    STYPE = cun_agg_stype,
    FINALFUNC = cun_agg_html_finalfunc,
    INITCOND = '("",0,0,0,0,value,false,false,center,false,intact,sumerian,FALSE)'
);

CREATE VIEW corpus_code AS
SELECT
    a.text_id,
    RANGE,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment ORDER BY corpus.sign_no) AS content
FROM (
    SELECT
        a.text_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.text_id = b.text_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus ON a.text_id = corpus.text_id
    AND RANGE @> corpus.sign_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    a.text_id,
    RANGE;

CREATE VIEW corpus_html AS
SELECT
    a.text_id,
    RANGE,
    cun_agg_html (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment ORDER BY corpus.sign_no)  AS content
FROM (
    SELECT
        a.text_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.text_id = b.text_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus ON a.text_id = corpus.text_id
    AND RANGE @> corpus.sign_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    a.text_id,
    RANGE;

CREATE VIEW corpus_lines_code AS
SELECT
    a.text_id,
    RANGE,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment ORDER BY corpus.sign_no) AS content
FROM (
    SELECT DISTINCT
        a.text_id,
        int4range(a.line_no, b.line_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.text_id = b.text_id
            AND a.line_no <= b.line_no) a
JOIN corpus ON a.text_id = corpus.text_id
    AND RANGE @> corpus.line_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    a.text_id,
    RANGE;

CREATE VIEW corpus_lines_html AS
SELECT
    a.text_id,
    RANGE,
    cun_agg_html (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment ORDER BY corpus.sign_no) AS content
FROM (
    SELECT DISTINCT
        a.text_id,
        int4range(a.line_no, b.line_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.text_id = b.text_id
            AND a.line_no <= b.line_no) a
JOIN corpus ON a.text_id = corpus.text_id
    AND RANGE @> corpus.line_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    a.text_id,
    RANGE;

CREATE VIEW corpus_texts_code AS
SELECT
    corpus.text_id,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment ORDER BY corpus.sign_no) AS content
FROM corpus
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    corpus.text_id;

CREATE VIEW corpus_texts_html AS
SELECT
    corpus.text_id,
    cun_agg_html (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment ORDER BY corpus.sign_no) AS content
FROM corpus
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    corpus.text_id;