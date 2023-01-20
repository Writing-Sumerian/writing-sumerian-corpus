
CREATE OR REPLACE FUNCTION corpus_replace (
        v_transliteration_id integer,
        v_pattern_id integer,
        v_sign_nos integer[],
        v_reference_ids integer[],
        v_reference_sign_nos integer[]
    )
    RETURNS SETOF replace.corpus
    STABLE
    ROWS 100
    LANGUAGE SQL
    AS
$BODY$

WITH "references" AS (
    SELECT 
        reference_id,
        sign_no
    FROM
        UNNEST(v_reference_ids, v_reference_sign_nos) AS _(reference_id, sign_no)
),
original AS (
    SELECT
        *,
        sign_no = ANY(v_sign_nos) AS matched
    FROM
        corpus
        LEFT JOIN words USING (transliteration_id, word_no)
    WHERE
        transliteration_id = v_transliteration_id
),
replacement_ AS (
    SELECT
        row_number() OVER (ORDER BY a.sign_no, b.sign_no) - 1 AS sign_no,
        COALESCE(b.value_id, a.value_id) AS value_id,
        COALESCE(b.sign_variant_id, a.sign_variant_id) AS sign_variant_id,
        COALESCE(b.custom_value, CASE WHEN reference_id IS NULL THEN a.custom_value ELSE NULL END) AS custom_value,
        COALESCE(b.type, a.type) AS type,
        COALESCE(b.indicator_type, a.indicator_type) AS indicator_type,
        COALESCE(b.phonographic, a.phonographic) AS phonographic,
        COALESCE(b.stem, a.stem) AS stem,
        COALESCE(
            b.word_no != lag(b.word_no) OVER w1, 
            a.word_no != lag(a.word_no) OVER w2, 
            false
        ) AS new_word,
        b.word_no IS NULL OR lag(b.word_no) OVER w1 IS NULL AS pattern_word,
        a.word_no AS word_no_pattern,
        b.word_no AS word_no_reference,
        COALESCE(
            b.compound_no != lag(b.compound_no) OVER w1, 
            a_words.compound_no != lag(a_words.compound_no) OVER w2, 
            false
        ) AS new_compound,
        b.compound_no IS NULL OR lag(b.compound_no) OVER w1 IS NULL AS pattern_compound,
        a_words.compound_no AS compound_no_pattern,
        b.compound_no AS compound_no_reference
    FROM
        replace.corpus_pattern a
        LEFT JOIN replace.words_pattern a_words USING (pattern_id, word_no)
        LEFT JOIN "references" ON (type = 'description' AND custom_value ~ '^[0-9]+' AND reference_id = custom_value::integer)
        LEFT JOIN original b ON (b.sign_no = "references".sign_no)
    WHERE
        a.pattern_id = v_pattern_id
    WINDOW  
        w1 AS (PARTITION BY a.sign_no ORDER BY a.sign_no, b.sign_no),
        w2 AS (ORDER BY a.sign_no)
),
replacement AS (
    SELECT
        v_transliteration_id AS transliteration_id,
        sign_no,
        sum(new_word::integer) OVER (ORDER BY sign_no) AS word_no,
        sum(new_compound::integer) OVER (ORDER BY sign_no) AS compound_no,
        value_id,
        sign_variant_id,
        custom_value,
        type,
        indicator_type,
        phonographic,
        stem,
        pattern_word,
        pattern_compound,
        CASE 
            WHEN pattern_word THEN word_no_pattern
            ELSE word_no_reference
        END AS word_no_ref,
        CASE 
            WHEN pattern_compound THEN compound_no_pattern
            ELSE compound_no_reference
        END AS compound_no_ref
    FROM
        replacement_
),
components_original AS (
    SELECT 
        row_number() OVER (ORDER BY sign_no, ord) AS component_no,
        sign_no,
        glyph_id
    FROM
        original
        LEFT JOIN sign_variants_composition USING (sign_variant_id)
        LEFT JOIN LATERAL UNNEST (glyph_ids) WITH ORDINALITY AS _(glyph_id, ord) ON TRUE
    WHERE
        matched
),
components_replacement AS (
    SELECT 
        row_number() OVER (ORDER BY sign_no, ord) AS component_no,
        sign_no,
        glyph_id
    FROM
        replacement
        LEFT JOIN sign_variants_composition USING (sign_variant_id)
        LEFT JOIN LATERAL UNNEST (glyph_ids) WITH ORDINALITY AS _(glyph_id, ord) ON TRUE
),
correspondence AS (
    SELECT DISTINCT
        a.sign_no AS sign_no_old,
        b.sign_no AS sign_no_new,
        COALESCE(a.sign_no - lag(a.sign_no) OVER (PARTITION BY b.sign_no ORDER BY a.sign_no), 0) AS gap
    FROM
        components_original a
        FULL JOIN components_replacement b USING (component_no, glyph_id)
),
retained_values AS (
    SELECT
        sign_no_new AS sign_no,
        min(line_no) AS line_no,
        condition_agg(condition) AS condition,
        string_agg(crits, '') AS crits,
        last(comment ORDER BY sign_no_old) AS comment,
        bool_or(newline) AS newline,
        last(inverted ORDER BY sign_no_old) AS inverted,
        last(ligature ORDER BY sign_no_old) AS ligature,
        min(sign_no_old) AS sign_no_old,
        min(word_no) AS word_no_old,
        min(compound_no) AS compound_no_old,
        bool_and_ex_last(NOT inverted AND NOT ligature)     -- cannot automatically merge inverted, ligatured oder commented on signs
        AND bool_and(sign_no_old IS NOT NULL)               -- all components have a correspondence in the old text
            AND bool_and(gap <= 1)                          -- no gaps within a new sign
            AS valid         
    FROM
        original
        JOIN correspondence ON (sign_no = sign_no_old)
    GROUP BY
        sign_no_new
),
patched_ AS (
    SELECT
        line_no,
        value_id,
        sign_variant_id,
        custom_value,
        type,
        indicator_type,
        phonographic,
        stem,
        condition,
        crits,
        comment,
        newline,
        inverted,
        ligature,
        sign_no AS sign_no_new,
        sign_no_old,
        word_no_old,
        word_no AS word_no_new,
        pattern_word,
        word_no_ref,
        compound_no_old,
        compound_no AS compound_no_new,
        pattern_compound,
        compound_no_ref,
        valid
    FROM
        replacement
        FULL JOIN retained_values USING (sign_no)
    UNION ALL
    SELECT
        line_no,
        value_id,
        sign_variant_id,
        custom_value,
        type,
        indicator_type,
        phonographic,
        stem,
        condition,
        crits,
        comment,
        newline,
        inverted,
        ligature,
        NULL AS sign_no_new,
        sign_no AS sign_no_old,
        word_no AS word_no_old,
        NULL AS word_no_new,
        false AS pattern_word,
        word_no AS word_no_ref,
        compound_no AS compound_no_old,
        NULL AS compound_no_new,
        false AS pattern_compound,
        compound_no AS compund_no_ref,
        true AS valid
    FROM
        original
    WHERE
        NOT matched
),
patched AS (
    SELECT
        *,
        row_number() OVER w1 - 1 AS sign_no_final,
        COALESCE(
            word_no_new != lag(word_no_new) OVER w1, 
            word_no_old != lag(word_no_old) OVER w1, 
            lag(word_no_old) OVER w1 IS NULL
        ) AS new_word,
        COALESCE(
            compound_no_new != lag(compound_no_new) OVER w1, 
            compound_no_old != lag(compound_no_old) OVER w1, 
            lag(compound_no_old) OVER w1 IS NULL
        ) AS new_compound,
        valid 
            AND COALESCE(compound_no_new IS NULL OR compound_no_old <= lag(compound_no_old) OVER w2 + 1, true)
            AND COALESCE(word_no_new IS NULL OR word_no_old <= lag(word_no_old) OVER w3 + 1, true) 
            AS valid_final
    FROM
        patched_
    WINDOW 
        w1 AS (ORDER BY sign_no_old, sign_no_new),
        w2 AS (PARTITION BY compound_no_new ORDER BY sign_no_old, sign_no_new),
        w3 AS (PARTITION BY word_no_new ORDER BY sign_no_old, sign_no_new)
)
SELECT
    v_transliteration_id,
    sign_no_final AS sign_no,
    line_no,
    sum(new_word::integer) OVER (ORDER BY sign_no_final) - 1,
    value_id,
    sign_variant_id,
    custom_value,
    type,
    indicator_type,
    phonographic,
    stem,
    condition,
    crits,
    comment,
    newline,
    inverted,
    ligature,
    v_pattern_id AS pattern_id,
    CASE WHEN new_word THEN pattern_word ELSE NULL END AS pattern_word,
    CASE WHEN new_word THEN word_no_ref ELSE NULL END AS word_no_ref,
    CASE WHEN new_compound THEN pattern_compound ELSE NULL END AS pattern_compound,
    CASE WHEN new_compound THEN compound_no_ref ELSE NULL END AS compound_no_ref,
    valid_final
FROM
    patched;

$BODY$;