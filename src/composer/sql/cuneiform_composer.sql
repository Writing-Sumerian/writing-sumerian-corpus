CREATE OR REPLACE FUNCTION cun_agg_sfunc (
    internal, 
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
    RETURNS internal
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_sfunc'
    LANGUAGE C
    IMMUTABLE;

CREATE OR REPLACE FUNCTION cun_agg_finalfunc (internal)
    RETURNS text[]
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
    STYPE = internal,
    FINALFUNC = cun_agg_finalfunc
);

CREATE OR REPLACE FUNCTION cun_agg_html_sfunc (
    internal, 
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
    RETURNS internal
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_html_sfunc'
    LANGUAGE C
    IMMUTABLE;

CREATE OR REPLACE FUNCTION cun_agg_html_finalfunc (internal)
    RETURNS text[]
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
    STYPE = internal,
    FINALFUNC = cun_agg_html_finalfunc
);


CREATE OR REPLACE FUNCTION mark_index_html (value text)
    RETURNS text
    STRICT
    IMMUTABLE
    LANGUAGE SQL
AS $BODY$
    SELECT regexp_replace(value, '([^0-9x×+*&%\.])([0-9x]+)', '\1<span class=''index''>\2</span>', 'g')
$BODY$;


CREATE VIEW corpus_code AS
SELECT
    a.text_id,
    RANGE,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
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
    cun_agg_html (COALESCE(mark_index_html(value), mark_index_html(signs.name), orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no)  AS content
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
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
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
    cun_agg_html (COALESCE(mark_index_html(value), mark_index_html(signs.name), orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
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
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
FROM corpus
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    corpus.text_id;

CREATE VIEW corpus_texts_html AS
SELECT
    corpus.text_id,
    cun_agg_html (COALESCE(mark_index_html(value), mark_index_html(signs.name), orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
FROM corpus
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
GROUP BY
    corpus.text_id;