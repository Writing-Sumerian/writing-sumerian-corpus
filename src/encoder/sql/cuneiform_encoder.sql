CREATE OR REPLACE VIEW values_encoded AS
WITH a(value, sign_spec, value_id, sign_variant_id) AS (
    SELECT
        value,
        glyphs,
        value_id,
        sign_variant_id,
        variant_type
    FROM
        value_variants
        JOIN values USING (value_id)
        JOIN sign_variants_composition USING (sign_id)
    UNION ALL
    SELECT
        value,
        null,
        value_id,
        sign_variant_id,
        variant_type
    FROM
        value_variants
        JOIN values USING (value_id)
        JOIN sign_variants_composition USING (sign_id)
    WHERE
        variant_type = 'default'
        AND NOT value ~ 'x'
    UNION ALL
    SELECT
        regexp_replace(value, '[0-9]*$', 'x'),
        glyphs,
        value_id,
        sign_variant_id,
        variant_type
    FROM
        value_variants
        JOIN values USING (value_id)
        JOIN sign_variants_composition USING (sign_id)
    WHERE
        NOT value ~ 'x'
    UNION ALL
    SELECT
        value,
        glyphs,
        value_id,
        sign_variant_id,
        variant_type
    FROM
        glyph_values 
        JOIN values USING (value_id)
        JOIN sign_variants_composition USING (sign_id, glyph_ids)
    UNION ALL
    SELECT
        value,
        null,
        value_id,
        sign_variant_id,
        variant_type
    FROM
        glyph_values 
        JOIN values USING (value_id)
        JOIN sign_variants_composition USING (sign_id, glyph_ids)
)
SELECT DISTINCT ON (value, sign_spec)
    value,
    sign_spec,
    value_id,
    sign_variant_id
FROM
    a
ORDER BY
    value,
    sign_spec,
    variant_type;



CREATE VIEW signs_encoded (sign, sign_spec, sign_variant_id) AS
SELECT
    glyphs,
    null,
    sign_variant_id
FROM
    sign_variants_composition
WHERE
    specific
UNION ALL
SELECT
    a.glyphs,
    b.glyphs,
    b.sign_variant_id
FROM
    sign_variants_composition a
    JOIN sign_variants_composition b USING (sign_id)
WHERE
    a.variant_type = 'default';



CREATE OR REPLACE PROCEDURE create_corpus_encoder (name text, source text, key text[])
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
    key_str text;
BEGIN

    SELECT string_agg(format('%I', val), ', ') INTO key_str FROM unnest(key) AS _(val);

    EXECUTE format(
        $$
        CREATE OR REPLACE VIEW %3$I AS
            WITH normalized_signs AS NOT MATERIALIZED (
                    WITH x AS (
                        SELECT
                            %1$s,
                            sign_no,
                            glyph_no,
                            normalize_operators(string_agg(op||COALESCE('('||glyphs||')', ''), '' ORDER BY component_no)) AS glyphs
                        FROM
                            %2$I
                            LEFT JOIN LATERAL split_glyphs(value) WITH ORDINALITY AS a(glyph, glyph_no) ON TRUE
                            LEFT JOIN LATERAL split_sign(glyph) WITH ORDINALITY AS b(component, op, component_no) ON TRUE
                            LEFT JOIN sign_map ON component = identifier
                        WHERE type = 'sign'
                        GROUP BY 
                            %1$s,
                            sign_no,
                            glyph_no
                    )
                    SELECT 
                        %1$s,
                        sign_no,
                        string_agg(glyphs, '.' ORDER BY glyph_no) AS glyphs
                    FROM
                        x
                    GROUP BY
                        %1$s,
                        sign_no),
                normalized_sign_specs AS NOT MATERIALIZED (
                    WITH x AS (
                        SELECT
                            %1$s,
                            sign_no,
                            glyph_no,
                            normalize_operators(string_agg(op||COALESCE('('||glyphs||')', ''), '' ORDER BY component_no)) AS glyphs
                        FROM
                            %2$I
                            LEFT JOIN LATERAL split_glyphs(sign_spec) WITH ORDINALITY AS a(glyph, glyph_no) ON TRUE
                            LEFT JOIN LATERAL split_sign(glyph) WITH ORDINALITY AS b(component, op, component_no) ON TRUE
                            LEFT JOIN sign_map ON component = identifier
                        WHERE sign_spec IS NOT NULL
                        GROUP BY 
                            %1$s,
                            sign_no,
                            glyph_no
                    )
                    SELECT 
                        %1$s,
                        sign_no,
                        string_agg(glyphs, '.' ORDER BY glyph_no) AS glyphs
                    FROM
                        x
                    GROUP BY
                        %1$s,
                        sign_no)
                SELECT
                    %1$s,
                    sign_no,
                    value_id,
                    sign_variant_id,
                    type
                FROM
                    %2$I s
                    LEFT JOIN normalized_sign_specs USING (%1$s, sign_no)
                    JOIN values_encoded ON ( normalized_sign_specs.glyphs IS NOT DISTINCT FROM values_encoded.sign_spec AND s.value = values_encoded.value)
                WHERE 
                    s.type = 'value'
                UNION ALL
                SELECT
                    %1$s,
                    sign_no,
                    NULL,
                    sign_variant_id,
                    type
                FROM
                    %2$I s
                    LEFT JOIN normalized_signs USING (%1$s, sign_no)
                    LEFT JOIN normalized_sign_specs USING (%1$s, sign_no)
                    JOIN signs_encoded ON normalized_signs.glyphs = signs_encoded.sign AND normalized_sign_specs.glyphs IS NOT DISTINCT FROM signs_encoded.sign_spec
                WHERE 
                    s.type = 'sign'
        $$,
        key_str,
        source,
        name
    );
END
$BODY$;