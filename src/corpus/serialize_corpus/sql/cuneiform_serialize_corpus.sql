CREATE OR REPLACE VIEW corpus_code AS
SELECT
    transliteration_id,
    COALESCE(character_print, CASE WHEN type = 'sign' THEN regexp_replace(custom_value, '^(\(?[A-ZĜḪŘŠṢṬ]+[0-9]*(@([gštvzn]|90|180))*\)?([×\.%&@\+]\(?[A-ZĜḪŘŠṢṬ]+[0-9]*(@([gštvzn]|90|180))*\)?)*)(?=\(|$)', '|\1|') ELSE custom_value END) AS value,
    sign_no, 
    word_no, 
    compound_no, 
    section_no,
    line_no, 
    type,
    indicator_type,
    phonographic, 
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
    LEFT JOIN characters_code ON (corpus.sign_variant_id = characters_code.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_code.value_id);


CREATE VIEW corpus_code_clean AS
SELECT
    transliteration_id,
    COALESCE(character_print, placeholder_code(type)) AS value,
    sign_no, 
    word_no, 
    compound_no, 
    type,
    indicator_type,
    phonographic, 
    stem,
    language
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN characters_code ON (corpus.sign_variant_id = characters_code.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_code.value_id);



CREATE VIEW corpus_serialized_range AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (value, sign_no, word_no, compound_no, section_no, line_no, type, indicator_type, phonographic, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment ORDER BY sign_no) AS content
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


CREATE VIEW lines_serialized AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (value, sign_no, word_no, compound_no, section_no, line_no, type, indicator_type, phonographic, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment ORDER BY sign_no) AS content
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


CREATE OR REPLACE VIEW transliterations_serialized AS
WITH a AS NOT MATERIALIZED (
SELECT
    transliteration_id,
    cun_agg (value, sign_no, word_no, compound_no, section_no, line_no, type, indicator_type, phonographic, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment ORDER BY sign_no) AS lines
FROM corpus_code
GROUP BY
    transliteration_id
),
b AS NOT MATERIALIZED (
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
c AS NOT MATERIALIZED (
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
)
SELECT
    transliteration_id,
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
    transliteration_id;