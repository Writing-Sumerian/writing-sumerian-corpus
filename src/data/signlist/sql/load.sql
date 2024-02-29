CREATE OR REPLACE PROCEDURE load_signlist (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

CALL signlist_drop_triggers();
DELETE FROM sign_variants_composition;
DELETE FROM sign_variants;

EXECUTE format('COPY glyphs(glyph_id, glyph, unicode) FROM %L CSV NULL ''\N''', path || 'glyphs.csv');
EXECUTE format('COPY glyph_synonyms(synonym, glyph_id) FROM %L CSV NULL ''\N''', path || 'glyph_synonyms.csv');
EXECUTE format('COPY glyph_values(value, value_id, glyph_ids) FROM %L CSV NULL ''\N''', path || 'glyph_values.csv');
EXECUTE format('COPY graphemes(grapheme_id, grapheme, mzl_no) FROM %L CSV NULL ''\N''', path || 'graphemes.csv');
EXECUTE format('COPY allographs(allograph_id, grapheme_id, glyph_id, variant_type, specific) FROM %L CSV NULL ''\N''', path || 'allographs.csv');
EXECUTE format('COPY allomorphs(allomorph_id, sign_id, variant_type, specific) FROM %L CSV NULL ''\N''', path || 'allomorphs.csv');
EXECUTE format('COPY allomorph_components(allomorph_id, pos, grapheme_id) FROM %L CSV NULL ''\N''', path || 'allomorph_components.csv');

INSERT INTO signs SELECT DISTINCT sign_id FROM allomorphs;
EXECUTE format('COPY sign_variants(sign_variant_id, sign_id, allomorph_id, allograph_ids, variant_type, specific) FROM %L CSV NULL ''\N''', path || 'sign_variants.csv');
INSERT INTO sign_variants_composition SELECT * FROM sign_variants_composition_view;

EXECUTE format('COPY value_variants(value_variant_id, value_id, value) FROM %L CSV NULL ''\N''', path || 'value_variants.csv');
EXECUTE format('COPY values(value_id, sign_id, main_variant_id, phonographic) FROM %L CSV NULL ''\N''', path || 'values.csv');

PERFORM setval('glyphs_glyph_id_seq', max(glyph_id)) FROM glyphs;
PERFORM setval('graphemes_grapheme_id_seq', max(grapheme_id)) FROM graphemes;
PERFORM setval('allographs_allograph_id_seq', max(allograph_id)) FROM allographs;
PERFORM setval('allomorphs_allomorph_id_seq', max(allomorph_id)) FROM allomorphs;
PERFORM setval('values_value_id_seq', max(value_id)) FROM values;
PERFORM setval('value_variants_value_variant_id_seq', max(value_variant_id)) FROM value_variants;
PERFORM setval('signs_sign_id_seq', max(sign_id)) FROM signs;
PERFORM setval('sign_variants_sign_variant_id_seq', max(sign_variant_id)) FROM sign_variants;

CALL signlist_create_triggers();

END

$BODY$;