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
    boolean,
    text, 
    text,
    boolean,
    pn_type,
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
    boolean,
    text, 
    text,
    boolean,
    pn_type,
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
    boolean,
    text, 
    text,
    boolean,
    pn_type,
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
    boolean,
    text, 
    text,
    boolean,
    pn_type,
    text,
    boolean
    ) (
    SFUNC = cun_agg_html_sfunc,
    STYPE = internal,
    FINALFUNC = cun_agg_html_finalfunc
);


CREATE OR REPLACE FUNCTION public.compose_sign_html (
    tree jsonb)
    RETURNS TEXT
    LANGUAGE 'plpython3u' 
    COST 100
    IMMUTABLE
    STRICT
    TRANSFORM FOR TYPE jsonb
AS $BODY$
    import re

    precedence = {'.': 0, '×': 1, '&': 2, '%': 3, '@': 3, '+': 4}
    modifiers = {'g': 'gunû', 'š': 'šeššig', 't': 'tenû', 'n': 'nutillû', 'k': 'kabatenû', 'z': 'zidatenû', 'i': 'inversum', 'v': 'inversum'}

    def stack(a, b):
        return f'<span class="stack">{a}<br/>{b}</span>'
    
    def rotate(a, val):
        return f'<span class="rot{val}">{a}</span>'

    def compose(node):
        op = node['op']
        if len(node['vals']) == 2:
            if op == '&':
                return stack(compose(node['vals'][0]), compose(node['vals'][1]))
            elif op == '%':
                return '<span class="cross">'+stack(compose(node['vals'][0]), compose(node['vals'][1]))+'</span>'
            elif op == '@':
                return stack(rotate(compose(node['vals'][0]), '180'), compose(node['vals'][1]))
            return parenthesize(node['vals'][0], precedence[op], True) + op + parenthesize(node['vals'][1], precedence[op], False)
        elif len(node['vals']) == 1:
            if op in ['45', '90', '180']:
                return rotate(compose(node['vals'][0]), op)
            return parenthesize(node['vals'][0], 100, True) + '<span class="modifier">'+modifiers[op]+'</span>'
        else:
            if re.fullmatch(r'(BAU|LAK|KWU|RSP|REC|ZATU|ELLES)[0-9]{3}', op):
                return re.sub(r'([0-9]+)$', r'<span class="slindex">\1</span>', op)
            else:
                return re.sub(r'(?<=[^0-9x])([0-9x]+)$', r'<span class="index">\1</span>', op)

    def parenthesize(node, prec, left):
        if len(node['vals']) == 2 and precedence[node['op']] + int(left) <= prec and node['op'] in ['.', '×']:
            return '(' + compose(node) + ')'
        return compose(node)

    return compose(tree)
$BODY$;


CREATE MATERIALIZED VIEW value_variants_html AS
SELECT
    value_variant_id,
    regexp_replace(value, '(?<=[^0-9x])([0-9x]+)$', '<span class=''index''>\1</span>') AS value_html
FROM
    value_variants;

CREATE MATERIALIZED VIEW values_html AS
SELECT
    value_id,
    value_html
FROM
    values
    JOIN value_variants_html ON main_variant_id = value_variant_id;

CREATE MATERIALIZED VIEW values_code AS
SELECT
    values.value_id,
    value AS value_code
FROM
    values
    JOIN value_variants ON main_variant_id = value_variant_id;

CREATE MATERIALIZED VIEW signs_code AS
SELECT
    sign_variant_id,
    string_agg(
        CASE WHEN allographs.variant_type = 'default' THEN grapheme ELSE glyph END,
        '.'
        ORDER BY ord
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
    string_agg(CASE WHEN allographs.variant_type = 'default' THEN grapheme_html ELSE glyph_html END, '.' ORDER BY ord) AS sign_html,
    string_agg(grapheme_html, '.'ORDER BY ord) AS graphemes_html,
    string_agg(glyph_html, '.' ORDER BY ord) AS glyphs_html
FROM
    sign_variants
    LEFT JOIN LATERAL unnest(allograph_ids) WITH ORDINALITY AS a(allograph_id, ord) ON TRUE
    LEFT JOIN allographs USING (allograph_id)
    LEFT JOIN graphemes USING (grapheme_id)
    LEFT JOIN glyphs USING (glyph_id)
    LEFT JOIN LATERAL compose_sign_html(parse_sign(grapheme)) AS b(grapheme_html) ON TRUE
    LEFT JOIN LATERAL compose_sign_html(parse_sign(glyph)) AS c(glyph_html) ON TRUE
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
    transliteration_id,
    COALESCE(value_code, custom_value) AS value,
    sign_code AS sign, 
    variant_type,
    sign_no, 
    word_no, 
    compound_no, 
    line_no, 
    properties, 
    stem, 
    condition, 
    language, 
    inverted, 
    newline,
    ligature,
    crits, 
    comment,
    capitalized,
    pn_type,
    compound_comment
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sign_variants USING (sign_variant_id) 
    LEFT JOIN signs_code USING (sign_variant_id)
    LEFT JOIN values_code USING (value_id);


CREATE VIEW corpus_code_clean AS
SELECT
    transliteration_id,
    COALESCE(value, placeholder((properties).type)) AS value,
    sign_code AS sign, 
    variant_type, 
    sign_no, 
    word_no, 
    compound_no, 
    properties, 
    stem,
    language
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sign_variants USING (sign_variant_id) 
    LEFT JOIN signs_code USING (sign_variant_id)
    LEFT JOIN values USING (value_id) 
    LEFT JOIN value_variants ON main_variant_id = value_variant_id;


CREATE VIEW corpus_html AS
SELECT
    transliteration_id,
    COALESCE(value_html, custom_value) AS value,
    sign_html AS sign, 
    variant_type, 
    sign_no, 
    word_no, 
    compound_no, 
    line_no, 
    properties, 
    stem, 
    condition, 
    language, 
    inverted, 
    newline,
    ligature,
    crits, 
    comment, 
    capitalized,
    pn_type,
    compound_comment
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sign_variants USING (sign_variant_id) 
    LEFT JOIN values_html USING (value_id)
    LEFT JOIN signs_html USING (sign_variant_id);

CREATE VIEW corpus_html_clean AS
SELECT
    transliteration_id,
    COALESCE(value_html, placeholder((properties).type)) AS value,
    sign_html AS sign, 
    variant_type, 
    sign_no, 
    word_no, 
    compound_no, 
    properties, 
    stem,
    language
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sign_variants USING (sign_variant_id) 
    LEFT JOIN values_html USING (value_id)
    LEFT JOIN signs_html USING (sign_variant_id);


CREATE VIEW corpus_code_range AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (value, sign, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, compound_comment, FALSE ORDER BY sign_no) AS content
FROM (
    SELECT
        a.transliteration_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus_code ON a.transliteration_id = corpus_code.transliteration_id
    AND RANGE @> corpus_code.sign_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_html_range AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg_html (value, sign, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, compound_comment, FALSE ORDER BY sign_no)  AS content
FROM (
    SELECT
        a.transliteration_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus_html ON a.transliteration_id = corpus_html.transliteration_id
    AND RANGE @> corpus_html.sign_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_code_lines AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (value, sign, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, 
        inverted, ligature, newline, crits, comment, capitalized, pn_type, compound_comment, FALSE ORDER BY sign_no) AS content
FROM (
    SELECT DISTINCT
        a.transliteration_id,
        int4range(a.line_no, b.line_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.line_no <= b.line_no) a
JOIN corpus_code ON a.transliteration_id = corpus_code.transliteration_id
    AND RANGE @> corpus_code.line_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE OR REPLACE VIEW corpus_code_transliterations AS
WITH a AS (
SELECT
    transliteration_id,
    cun_agg (value, sign, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, 
        inverted, ligature, newline, crits, comment, capitalized, pn_type, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus_code
GROUP BY
    transliteration_id
),
b AS (
SELECT
    a.transliteration_id,
    block_no,
    string_agg(line || E'\t' || content || COALESCE(E'\n# '|| line_comment, ''), E'\n' ORDER BY line_no) AS content
FROM
    a
    LEFT JOIN LATERAL UNNEST(lines) WITH ORDINALITY AS content(content, line_no_plus_one) ON TRUE
    LEFT JOIN lines ON a.transliteration_id = lines.transliteration_id AND line_no_plus_one = line_no + 1
GROUP BY
    a.transliteration_id,
    block_no
),
c AS (
SELECT
    transliteration_id,
    surface_no,
    string_agg('@' || block_type::text || COALESCE(' '||block_data, '') || E'\n' || content || COALESCE(E'\n# '|| block_comment, ''), E'\n' ORDER BY block_no) AS content
FROM
    b
    LEFT JOIN blocks USING (transliteration_id, block_no)
GROUP BY
    transliteration_id,
    surface_no
),
d AS (
SELECT
    transliteration_id,
    object_no,
    string_agg('@' || surface_type::text || COALESCE(' '||surface_data, '') || E'\n' || content || COALESCE(E'\n# '|| surface_comment, ''), E'\n' ORDER BY surface_no) AS content
FROM
    c
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
GROUP BY
    transliteration_id,
    object_no
)
SELECT
    transliteration_id,
    string_agg('@' || object_type::text || COALESCE(' '||object_data, '') || E'\n' || content || COALESCE(E'\n# '|| object_comment, ''), E'\n' ORDER BY object_no) AS content
FROM
    d
    LEFT JOIN objects USING (transliteration_id, object_no)
GROUP BY
    transliteration_id;


CREATE VIEW corpus_html_transliterations AS
WITH a AS (
SELECT
    transliteration_id,
    cun_agg_html (value, sign, variant_type, sign_no, word_no, compound_no, line_no, properties, stem, condition, language, 
        inverted, ligature, newline, crits, comment, capitalized, pn_type, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus_html
GROUP BY
    transliteration_id
)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a, LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no);