





CREATE OR REPLACE PROCEDURE encode_corpus2 (source text, target text, key text)
    LANGUAGE PLPGSQL
    AS $BODY$
    
BEGIN

EXECUTE format(
    $$
    CREATE TEMPORARY VIEW normalized_signs AS
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
        sign_no
    $$, 
    key,
    source);

EXECUTE format(
    $$
    CREATE TEMPORARY VIEW normalized_sign_specs AS
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
        sign_no
    $$, 
    key,
    source);


-- values
EXECUTE format(
    $$
    UPDATE %1$s
    SET
        value_id = value_map.value_id,
        sign_variant_id = value_map.sign_variant_id
    FROM
        %2$I s
        JOIN value_map USING (value)
    WHERE 
        value_map.specific AND
        %1$s.%3$I = s.%3$I AND
        %1$s.sign_no = s.sign_no AND
        s.sign_spec IS NULL AND 
        s.type != 'sign' AND 
        s.type != 'number'
    $$,
    target, 
    source,
    key);

-- values with sign_spec
EXECUTE format(
    $$
    UPDATE %1$s
    SET
        value_id = value_map.value_id,
        sign_variant_id = value_map.sign_variant_id
    FROM
        %2$I s
        JOIN normalized_sign_specs USING (%3$I, sign_no)
        JOIN value_map USING (glyphs)
    WHERE 
        ((s.value !~ 'x' AND s.value = value_map.value) OR  
            (s.value ~ 'x' AND replace(s.value, 'x', '') = regexp_replace(value_map.value, '[x0-9]+', ''))) AND
        %1$s.%3$I = s.%3$I AND
        %1$s.sign_no = s.sign_no AND
        s.sign_spec IS NOT NULL AND 
        s.type != 'sign' AND 
        s.type != 'number'
    $$,
    target, 
    source,
    key);

-- signs
EXECUTE format(
    $$
    UPDATE %1$s
    SET
        value_id = NULL,
        sign_variant_id = sign_variants_text.sign_variant_id
    FROM
        %2$I s
        JOIN normalized_signs USING (%3$I, sign_no)
        JOIN sign_variants_text USING (glyphs)
    WHERE
        specific AND
        %1$s.%3$I = s.%3$I AND
        %1$s.sign_no = s.sign_no AND
        s.type = 'sign' AND 
        s.sign_spec IS NULL
    $$,
    target,
    source,
    key);

-- signs with sign_spec
EXECUTE format(
    $$
    UPDATE %1$s
    SET
        value_id = NULL,
        sign_variant_id = sign_variants_text.sign_variant_id
    FROM
        %2$I s
        JOIN normalized_sign_specs USING (%3$I, sign_no)
        JOIN sign_variants_text USING (glyphs)
        JOIN sign_map ON identifier = value
    WHERE 
        sign_map.graphemes = sign_variants_text.graphemes AND
        %1$s.%3$I = s.%3$I AND
        %1$s.sign_no = s.sign_no AND
        s.type = 'sign' AND 
        s.sign_spec IS NOT NULL
    $$,
    target,
    source,
    key);

-- numbers
EXECUTE format(
    $$
    UPDATE %1$s
    SET
        value_id = NULL,
        sign_variant_id = sign_variants_text.sign_variant_id
    FROM
        %2$I s
        LEFT JOIN normalized_sign_specs USING (%3$I, sign_no)
        LEFT JOIN sign_variants_text USING (glyphs)
    WHERE 
        specific AND
        %1$s.%3$I = s.%3$I AND
        %1$s.sign_no = s.sign_no AND
        s.type = 'number'
    $$,
    target,
    source,
    key);

DROP VIEW normalized_signs;
DROP VIEW normalized_sign_specs;

END
$BODY$;


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
        CREATE OR REPLACE VIEW @extschema@.%3$I AS
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
                    value_map.value_id,
                    value_map.sign_variant_id
                FROM
                    %2$I s
                    LEFT JOIN value_map USING (value)
                WHERE 
                    (value_map.specific OR value_map.specific IS NULL) AND
                    s.sign_spec IS NULL AND 
                    s.type != 'sign' AND 
                    s.type != 'number'
                UNION ALL
                SELECT
                    %1$s,
                    sign_no,
                    value_map.value_id,
                    value_map.sign_variant_id
                FROM
                    %2$I s
                    LEFT JOIN normalized_sign_specs USING (%1$s, sign_no)
                    LEFT JOIN value_map USING (glyphs)
                WHERE 
                    ((s.value !~ 'x' AND s.value = value_map.value) OR  
                        (s.value ~ 'x' AND replace(s.value, 'x', '') = regexp_replace(value_map.value, '[x0-9]+', '')) OR
                        value_map.value IS NULL) AND
                    s.sign_spec IS NOT NULL AND 
                    s.type != 'sign' AND 
                    s.type != 'number'
                UNION ALL
                SELECT
                    %1$s,
                    sign_no,
                    NULL,
                    sign_variants_text.sign_variant_id
                FROM
                    %2$I s
                    LEFT JOIN normalized_signs USING (%1$s, sign_no)
                    LEFT JOIN sign_variants_text USING (glyphs)
                WHERE
                    (sign_variants_text.specific OR sign_variants_text.specific IS NULL) AND
                    s.type = 'sign' AND 
                    s.sign_spec IS NULL
                UNION ALL
                SELECT
                    %1$s,
                    sign_no,
                    NULL,
                    sign_variants_text.sign_variant_id
                FROM
                    %2$I s
                    LEFT JOIN normalized_sign_specs USING (%1$s, sign_no)
                    LEFT JOIN sign_variants_text USING (glyphs)
                    LEFT JOIN sign_map ON sign_variants_text.sign_variant_id IS NOT NULL AND identifier = value
                WHERE 
                    (sign_map.graphemes = sign_variants_text.graphemes OR sign_variants_text.graphemes IS NULL) AND
                    s.type = 'sign' AND 
                    s.sign_spec IS NOT NULL
                UNION ALL
                SELECT
                    %1$s,
                    sign_no,
                    NULL,
                    sign_variants_text.sign_variant_id
                FROM
                    %2$I s
                    LEFT JOIN normalized_sign_specs USING (%1$s, sign_no)
                    LEFT JOIN sign_variants_text USING (glyphs)
                WHERE 
                    (sign_variants_text.specific OR sign_variants_text.specific IS NULL) AND
                    s.type = 'number'
        $$,
        key_str,
        source,
        name
    );
END
$BODY$;