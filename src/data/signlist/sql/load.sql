CREATE OR REPLACE PROCEDURE load_signlist (v_path text)
  LANGUAGE PLPGSQL
AS $BODY$

BEGIN

  SET CONSTRAINTS ALL DEFERRED;

  CALL @extschema@.signlist_drop_triggers();
  DELETE FROM @extschema@.sign_variants_composition;
  DELETE FROM @extschema@.sign_variants;

  EXECUTE format('COPY @extschema@.glyphs(glyph_id, glyph, unicode) FROM %L CSV NULL ''\N''', v_path || 'glyphs.csv');
  EXECUTE format('COPY @extschema@.glyph_synonyms(synonym, glyph_id) FROM %L CSV NULL ''\N''', v_path || 'glyph_synonyms.csv');
  EXECUTE format('COPY @extschema@.glyph_values(value, value_id, glyph_ids) FROM %L CSV NULL ''\N''', v_path || 'glyph_values.csv');
  EXECUTE format('COPY @extschema@.graphemes(grapheme_id, grapheme, mzl_no) FROM %L CSV NULL ''\N''', v_path || 'graphemes.csv');
  EXECUTE format('COPY @extschema@.allographs(allograph_id, grapheme_id, glyph_id, variant_type, specific) FROM %L CSV NULL ''\N''', v_path || 'allographs.csv');
  EXECUTE format('COPY @extschema@.allomorphs(allomorph_id, sign_id, variant_type, specific) FROM %L CSV NULL ''\N''', v_path || 'allomorphs.csv');
  EXECUTE format('COPY @extschema@.allomorph_components(allomorph_id, pos, grapheme_id) FROM %L CSV NULL ''\N''', v_path || 'allomorph_components.csv');

  INSERT INTO @extschema@.signs OVERRIDING SYSTEM VALUE SELECT DISTINCT sign_id FROM @extschema@.allomorphs;
  EXECUTE format('COPY @extschema@.sign_variants(sign_variant_id, sign_id, allomorph_id, allograph_ids, variant_type, specific) FROM %L CSV NULL ''\N''', v_path || 'sign_variants.csv');
  INSERT INTO @extschema@.sign_variants_composition SELECT * FROM @extschema@.sign_variants_composition_view;

  EXECUTE format('COPY @extschema@.value_variants(value_variant_id, value_id, value) FROM %L CSV NULL ''\N''', v_path || 'value_variants.csv');
  EXECUTE format('COPY @extschema@.values(value_id, sign_id, main_variant_id, phonographic) FROM %L CSV NULL ''\N''', v_path || 'values.csv');

  PERFORM setval(pg_get_serial_sequence('@extschema@.glyphs', 'glyph_id'), max(glyph_id)) FROM @extschema@.glyphs;
  PERFORM setval(pg_get_serial_sequence('@extschema@.graphemes', 'grapheme_id'), max(grapheme_id)) FROM @extschema@.graphemes;
  PERFORM setval(pg_get_serial_sequence('@extschema@.allographs', 'allograph_id'), max(allograph_id)) FROM @extschema@.allographs;
  PERFORM setval(pg_get_serial_sequence('@extschema@.allomorphs', 'allomorph_id'), max(allomorph_id)) FROM @extschema@.allomorphs;
  PERFORM setval(pg_get_serial_sequence('@extschema@.values', 'value_id'), max(value_id)) FROM @extschema@.values;
  PERFORM setval(pg_get_serial_sequence('@extschema@.value_variants', 'value_variant_id'), max(value_variant_id)) FROM @extschema@.value_variants;
  PERFORM setval(pg_get_serial_sequence('@extschema@.signs', 'sign_id'), max(sign_id)) FROM @extschema@.signs;
  PERFORM setval(pg_get_serial_sequence('@extschema@.sign_variants', 'sign_variant_id'), max(sign_variant_id)) FROM @extschema@.sign_variants;

  CALL @extschema@.signlist_create_triggers();

END

$BODY$;