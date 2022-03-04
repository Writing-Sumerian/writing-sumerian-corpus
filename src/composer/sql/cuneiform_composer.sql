CREATE OR REPLACE FUNCTION cun_agg_sfunc (
    internal, 
    text, 
    text,
    sign_variant_type, 
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
    text,
    text,
    boolean
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
    text,
    sign_variant_type, 
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
    text,
    text,
    boolean
    ) (
    SFUNC = cun_agg_sfunc,
    STYPE = internal,
    FINALFUNC = cun_agg_finalfunc
);

CREATE OR REPLACE FUNCTION cun_agg_html_sfunc (
    internal, 
    text, 
    text,
    sign_variant_type,  
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
    text,
    text,
    boolean
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
    text,
    sign_variant_type, 
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
    text,
    text,
    boolean
    ) (
    SFUNC = cun_agg_html_sfunc,
    STYPE = internal,
    FINALFUNC = cun_agg_html_finalfunc
);

CREATE OR REPLACE FUNCTION display_sign_html (
    sign text
    )
    RETURNS text
    LANGUAGE SQL
    STRICT 
    IMMUTABLE
    AS
$BODY$
SELECT 
    h AS sign_html
FROM
    regexp_replace(sign, '(?<!LAK|KWU|RSP|REC)(?<=[^0-9x×+*&%\.@])([0-9x]+)', '<span class=''index''>\1</span>') a,
    LATERAL replace(a, '@g', '<span class=''modifier''>gunû</span>') b,
    LATERAL replace(b, '@š', '<span class=''modifier''>šeššig</span>') c,
    LATERAL replace(c, '@t', '<span class=''modifier''>tenû</span>') d,
    LATERAL replace(d, '@n', '<span class=''modifier''>nutillû</span>') e,
    LATERAL replace(e, '@k', '<span class=''modifier''>kabatenû</span>') f,
    LATERAL replace(f, '@z', '<span class=''modifier''>zidatenû</span>') g,
    LATERAL replace(g, '@i', '<span class=''modifier''>inversum</span>') h
$BODY$;

CREATE MATERIALIZED VIEW values_html AS
SELECT
    values.value_id,
    regexp_replace(value, '(?<=[^0-9x])([0-9x]+)$', '<span class=''index''>\1</span>') AS value_html
FROM
    values
    JOIN value_variants ON main_variant_id = value_variant_id;

CREATE MATERIALIZED VIEW signs_code AS
SELECT
    sign_variant_id,
    string_agg(
        CASE WHEN allographs.variant_type = 'default' THEN grapheme ELSE glyph END,
        '.'
    ) AS sign_code
FROM
    sign_variants
    LEFT JOIN LATERAL unnest(allograph_ids) WITH ORDINALITY AS a(allograph_id, ord) ON TRUE
    LEFT JOIN allographs USING (allograph_id)
    LEFT JOIN graphemes USING (grapheme_id)
    LEFT JOIN glyphs USING (glyph_id)
GROUP BY
    sign_variant_id;

CREATE MATERIALIZED VIEW signs_html AS
SELECT
    sign_variant_id,
    string_agg(display_sign_html(
        CASE WHEN allographs.variant_type = 'default' THEN grapheme ELSE glyph END
        ),
        '.'
    ) AS sign_html
FROM
    sign_variants
    LEFT JOIN LATERAL unnest(allograph_ids) WITH ORDINALITY AS a(allograph_id, ord) ON TRUE
    LEFT JOIN allographs USING (allograph_id)
    LEFT JOIN graphemes USING (grapheme_id)
    LEFT JOIN glyphs USING (glyph_id)
GROUP BY
    sign_variant_id;

CREATE OR REPLACE FUNCTION placeholder (type SIGN_TYPE)
    RETURNS text
    STRICT
    IMMUTABLE
    LANGUAGE SQL
AS $BODY$
    SELECT
        '<span class="placeholder">' 
        ||
        CASE type
        WHEN 'number' THEN
            'N'
        WHEN 'description' THEN
            'DESC'
        WHEN 'punctuation' THEN
            '|'
        WHEN 'damage' THEN
            '…'
        ELSE
            'X'
        END 
        ||
        '</span>'
$BODY$;



CREATE VIEW corpus_code AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (COALESCE(value, number, orig_value), sign_code, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment, compound_comment, FALSE ORDER BY corpus.sign_no) AS content
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
LEFT JOIN signs_code USING (sign_variant_id)
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_html AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg_html (COALESCE(value_html, number, orig_value), sign_html, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment, compound_comment, FALSE ORDER BY sign_no)  AS content
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
LEFT JOIN values_html USING (value_id)
LEFT JOIN signs_html USING (sign_variant_id)
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_lines_code AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (COALESCE(value, number, orig_value), sign_code, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment, compound_comment, FALSE ORDER BY sign_no) AS content
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
LEFT JOIN signs_code USING (sign_variant_id)
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_transliterations_code AS
WITH a AS (
SELECT
    corpus.transliteration_id,
    cun_agg (COALESCE(value, number, orig_value), sign_code, variant_type, sign_no,word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus
LEFT JOIN signs_code USING (sign_variant_id)
GROUP BY
    corpus.transliteration_id)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a, LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no);

CREATE VIEW corpus_transliterations_html AS
WITH a AS (
SELECT
    corpus.transliteration_id,
    cun_agg_html (COALESCE(value_html, orig_value), sign_html, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, comment, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus
LEFT JOIN values_html USING (value_id)
LEFT JOIN signs_html USING (sign_variant_id)
GROUP BY
    corpus.transliteration_id)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a, LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no);