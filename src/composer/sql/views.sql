CREATE VIEW characters_composed AS
SELECT
    value_id,
    sign_variant_id,
    value_code AS character_code,
    value_html AS character_html
FROM
    values_composed
UNION ALL
SELECT
    NULL AS value_id,
    sign_variant_id,
    sign_code AS character_code,
    sign_html AS character_html
FROM
    signs_composed;


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


CREATE OR REPLACE VIEW corpus_code AS
SELECT
    transliteration_id,
    COALESCE(character_code, CASE WHEN (properties).type = 'sign' THEN regexp_replace(custom_value, '^(\(?[A-ZĜḪŘŠṢṬ]+[0-9]*(@([gštvzn]|90|180))*\)?([×\.%&@\+]\(?[A-ZĜḪŘŠṢṬ]+[0-9]*(@([gštvzn]|90|180))*\)?)*)(?=\(|$)', '|\1|') ELSE custom_value END) AS value,
    NULL AS sign,
    sign_no, 
    word_no, 
    compound_no, 
    section_no,
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
    section_name,
    compound_comment
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sections USING (transliteration_id, section_no)
    LEFT JOIN characters_composed ON (corpus.sign_variant_id = characters_composed.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_composed.value_id);


CREATE VIEW corpus_code_clean AS
SELECT
    transliteration_id,
    COALESCE(character_code, placeholder((properties).type)) AS value,
    NULL AS sign,
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
    LEFT JOIN characters_composed ON (corpus.sign_variant_id = characters_composed.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_composed.value_id);


CREATE OR REPLACE VIEW corpus_html AS
SELECT
    transliteration_id,
    COALESCE(character_html, custom_value) AS value,
    NULL AS sign, 
    sign_no, 
    word_no, 
    compound_no, 
    section_no,
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
    section_name,
    compound_comment
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sections USING (transliteration_id, section_no)
    LEFT JOIN characters_composed ON (corpus.sign_variant_id = characters_composed.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_composed.value_id);

CREATE VIEW corpus_html_clean AS
SELECT
    transliteration_id,
    COALESCE(character_html, placeholder((properties).type)) AS value,
    NULL AS sign,
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
    LEFT JOIN characters_composed ON (corpus.sign_variant_id = characters_composed.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_composed.value_id);



CREATE VIEW corpus_code_range AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (value, sign, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS content
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
    cun_agg_html (value, sign, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no)  AS content
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
    cun_agg (value, sign, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS content
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
    cun_agg (value, sign, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus_code
GROUP BY
    transliteration_id
),
b AS (
SELECT
    lines.transliteration_id,
    block_no,
    string_agg(line || E'\t' || COALESCE(content, '') || COALESCE(E'\n# '|| line_comment, ''), E'\n' ORDER BY line_no) AS content
FROM
    a
    LEFT JOIN LATERAL UNNEST(lines) WITH ORDINALITY AS content(content, line_no_plus_one) ON TRUE
    RIGHT JOIN lines ON a.transliteration_id = lines.transliteration_id AND line_no_plus_one = line_no + 1
GROUP BY
    lines.transliteration_id,
    block_no
),
c AS (
SELECT
    transliteration_id,
    surface_no,
    string_agg(
        CASE 
            WHEN block_type != 'block' OR block_data IS NOT NULL THEN
                '@' || block_type::text || COALESCE(' '||block_data, '') || COALESCE(E'\n# '|| block_comment, '') || COALESCE(E'\n' || content, '')
            ELSE
                COALESCE(content, '')
        END,
        E'\n' 
        ORDER BY block_no
    ) AS content
FROM
    b
    RIGHT JOIN blocks USING (transliteration_id, block_no)
GROUP BY
    transliteration_id,
    surface_no
),
d AS (
SELECT
    transliteration_id,
    object_no,
    string_agg(
        CASE 
            WHEN surface_type != 'surface' OR surface_data IS NOT NULL THEN
                '@' || surface_type::text || COALESCE(' '||surface_data, '') || COALESCE(E'\n# '|| surface_comment, '') || COALESCE(E'\n' || content, '')
            ELSE
                COALESCE(content, '')
        END, 
        E'\n' 
        ORDER BY surface_no
    ) AS content
FROM
    c
    RIGHT JOIN surfaces USING (transliteration_id, surface_no)
GROUP BY
    transliteration_id,
    object_no
)
SELECT
    transliteration_id,
    string_agg(
        CASE 
            WHEN object_type != 'object' OR object_data IS NOT NULL THEN
                '@' || object_type::text || COALESCE(' '||object_data, '') || COALESCE(E'\n# '|| object_comment, '') || COALESCE(E'\n' || content, '')
            ELSE
                COALESCE(content, '')
        END, 
        E'\n' 
        ORDER BY object_no
    ) AS content
FROM
    d
    RIGHT JOIN objects USING (transliteration_id, object_no)
GROUP BY
    transliteration_id;


CREATE VIEW corpus_html_transliterations AS
WITH a AS (
SELECT
    transliteration_id,
    cun_agg_html (value, sign, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, ligature, newline, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus_html
GROUP BY
    transliteration_id
)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a, LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no);