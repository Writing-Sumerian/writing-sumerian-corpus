CREATE OR REPLACE VIEW corpus_html AS
SELECT
    transliteration_id,
    COALESCE(character_print, custom_value) AS value,
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
    LEFT JOIN characters_html ON (corpus.sign_variant_id = characters_html.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_html.value_id);

CREATE VIEW corpus_html_clean AS
SELECT
    transliteration_id,
    COALESCE(character_print, placeholder_html(type)) AS value,
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
    LEFT JOIN characters_html ON (corpus.sign_variant_id = characters_html.sign_variant_id AND corpus.value_id IS NOT DISTINCT FROM characters_html.value_id);


CREATE VIEW corpus_html_range AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg_html (value, sign_no, word_no, compound_no, section_no, line_no, type, indicator_type, phonographic, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE, VARIADIC ARRAY[]::integer[] ORDER BY sign_no)  AS content
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


CREATE VIEW corpus_html_transliterations AS
WITH a AS (
SELECT
    transliteration_id,
    cun_agg_html (value, sign_no, word_no, compound_no, section_no, line_no, type, indicator_type, phonographic, stem, condition, language, 
        inverted, ligature, newline, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE, VARIADIC ARRAY[]::integer[] ORDER BY sign_no) AS lines
FROM corpus_html
GROUP BY
    transliteration_id
)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a, LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no);