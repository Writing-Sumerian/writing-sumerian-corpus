
CREATE MATERIALIZED VIEW sign_map (identifier, graphemes, grapheme_ids, glyphs, glyph_ids) AS
SELECT
    upper(value),
    string_agg(grapheme, '.' ORDER BY pos),
    NULLIF(array_agg(graphemes.grapheme_id ORDER BY pos)::int[], ARRAY[NULL]::int[]),
    string_agg(glyph, '.' ORDER BY pos),
    NULLIF(array_agg(glyph_id ORDER BY pos)::int[], ARRAY[NULL]::int[])
FROM
    value_variants
    JOIN values USING (value_id)
    JOIN allomorphs USING (sign_id)
    JOIN allomorph_components ON allomorphs.allomorph_id = allomorph_components.allomorph_id AND allomorphs.variant_type = 'default'
    LEFT JOIN graphemes USING (grapheme_id)
    LEFT JOIN allographs ON allomorph_components.grapheme_id = allographs.grapheme_id AND allographs.variant_type = 'default'
    LEFT JOIN glyphs USING (glyph_id)
WHERE
    value !~ 'x'
GROUP BY
    value
UNION
SELECT
    upper(value),
    null,
    null,
    string_agg(glyph, '.' ORDER BY ord),
    glyph_ids
FROM
    glyph_values
    LEFT JOIN LATERAL UNNEST(glyph_ids) WITH ORDINALITY AS _(glyph_id, ord) ON TRUE
    LEFT JOIN glyphs USING (glyph_id)
GROUP BY
    value
UNION
SELECT
    synonym,
    null,
    null,
    glyph,
    ARRAY[glyph_id]
FROM
    glyph_synonyms
    JOIN glyphs USING (glyph_id)
UNION
SELECT
    grapheme,
    grapheme,
    ARRAY[graphemes.grapheme_id],
    glyph,
    NULLIF(ARRAY[glyph_id]::int[], ARRAY[NULL]::int[])
FROM
    graphemes
    LEFT JOIN allographs ON graphemes.grapheme_id = allographs.grapheme_id AND variant_type = 'default'
    LEFT JOIN glyphs USING (glyph_id)
WHERE grapheme NOT IN (SELECT upper(value) FROM value_variants)
UNION
SELECT
    glyph,
    grapheme,
    NULLIF(ARRAY[grapheme_id]::int[], ARRAY[NULL]::int[]),
    glyph,
    ARRAY[glyphs.glyph_id]
FROM
    glyphs
    LEFT JOIN allographs ON glyphs.glyph_id = allographs.glyph_id AND specific
    LEFT JOIN graphemes USING (grapheme_id)
WHERE glyph NOT IN (SELECT upper(value) FROM value_variants)
UNION
SELECT
    'X',
    'X',
    NULL,
    'X',
    NULL;

CREATE MATERIALIZED VIEW value_map (value, value_id, sign_variant_id, glyphs, graphemes, glyphs_required, specific) AS
SELECT
    value,
    value_id,
    sign_variant_id,
    glyphs,
    graphemes,
    FALSE,
    value !~ 'x' AND sign_variants_composition.variant_type = 'default'
FROM
    value_variants
    JOIN values USING (value_id)
    JOIN allomorphs USING (sign_id)
    JOIN sign_variants_composition USING (allomorph_id)
UNION ALL
SELECT
    value,
    value_id,
    sign_variant_id,
    glyphs,
    graphemes,
    TRUE,
    count(*) OVER (PARTITION BY value) = 1
FROM
    glyph_values 
    JOIN sign_variants_composition USING (glyph_ids)
    JOIN allomorphs USING (allomorph_id)
    JOIN values USING (sign_id, value_id);



CREATE VIEW signlist AS 
SELECT 
    sign_id, 
    sign_variant_id,
    graphemes,
    glyphs,
    unicode,
    sign_variants_composition.variant_type,
    sign_variants_composition.specific,
    value_id, 
    value_variant_id, 
    value, 
    value_variant_id = values.main_variant_id AS main 
FROM value_variants 
    JOIN values USING (value_id)
    JOIN allomorphs USING (sign_id) 
    JOIN sign_variants_composition USING (allomorph_id)
ORDER BY 
    sign_id, 
    graphemes,
    glyphs,
    value_id, 
    main DESC,
    value;







CREATE OR REPLACE PROCEDURE signlist_refresh ()
    LANGUAGE PLPGSQL
    AS 
$BODY$
    BEGIN
    REFRESH MATERIALIZED VIEW sign_map;
    REFRESH MATERIALIZED VIEW value_map;
    END
$BODY$;
