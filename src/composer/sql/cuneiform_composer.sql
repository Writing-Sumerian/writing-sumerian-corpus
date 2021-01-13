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
    IMMUTABLE
    COST 100;

CREATE OR REPLACE FUNCTION cun_agg_finalfunc (internal)
    RETURNS text[]
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_finalfunc'
    LANGUAGE C
    STRICT 
    IMMUTABLE
    COST 100;

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
    IMMUTABLE
    COST 10000;

CREATE OR REPLACE FUNCTION cun_agg_html_finalfunc (internal)
    RETURNS text[]
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_html_finalfunc'
    LANGUAGE C
    STRICT 
    IMMUTABLE
    COST 100;

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

CREATE OR REPLACE FUNCTION placeholder (type SIGN_TYPE)
    RETURNS text
    STRICT
    IMMUTABLE
    LANGUAGE SQL
AS $BODY$
    SELECT
        CASE type
        WHEN 'number' THEN
            'N'
        WHEN 'desc' THEN
            'DESC'
        WHEN 'punctuation' THEN
            '|'
        WHEN 'damage' THEN
            '…'
        ELSE
            'X'
        END
$BODY$;



CREATE VIEW corpus_code AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
FROM (
    SELECT
        a.transliteration_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus ON a.transliteration_id = corpus.transliteration_id
    AND RANGE @> corpus.sign_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.transliteration_id = words.transliteration_id AND corpus.word_no = words.word_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_html AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg_html (COALESCE(mark_index_html(value), mark_index_html(signs.name), orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no)  AS content
FROM (
    SELECT
        a.transliteration_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus ON a.transliteration_id = corpus.transliteration_id
    AND RANGE @> corpus.sign_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.transliteration_id = words.transliteration_id AND corpus.word_no = words.word_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_lines_code AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
FROM (
    SELECT DISTINCT
        a.transliteration_id,
        int4range(a.line_no, b.line_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.line_no <= b.line_no) a
JOIN corpus ON a.transliteration_id = corpus.transliteration_id
    AND RANGE @> corpus.line_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.transliteration_id = words.transliteration_id AND corpus.word_no = words.word_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_lines_html AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg_html (COALESCE(mark_index_html(value), mark_index_html(signs.name), orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS content
FROM (
    SELECT DISTINCT
        a.transliteration_id,
        int4range(a.line_no, b.line_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.line_no <= b.line_no) a
JOIN corpus ON a.transliteration_id = corpus.transliteration_id
    AND RANGE @> corpus.line_no
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.transliteration_id = words.transliteration_id AND corpus.word_no = words.word_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_transliterations_code AS
WITH a AS (
SELECT
    corpus.transliteration_id,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS lines
FROM corpus
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.transliteration_id = words.transliteration_id AND corpus.word_no = words.word_no
GROUP BY
    corpus.transliteration_id)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a LEFT JOIN LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no) ON TRUE;

CREATE VIEW corpus_transliterations_html AS
WITH a AS (
SELECT
    corpus.transliteration_id,
    cun_agg_html (COALESCE(mark_index_html(value), mark_index_html(signs.name), orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no) AS lines
FROM corpus
LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
LEFT JOIN signs USING (sign_id)
JOIN words ON corpus.transliteration_id = words.transliteration_id AND corpus.word_no = words.word_no
GROUP BY
    corpus.transliteration_id)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a LEFT JOIN LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no) ON TRUE;