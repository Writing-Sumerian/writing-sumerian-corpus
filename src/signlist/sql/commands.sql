CREATE OR REPLACE PROCEDURE add_value (
  sign_id integer, 
  value text,
  phonographic boolean DEFAULT NULL,
  value_id INOUT integer DEFAULT NULL,
  value_variant_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO values VALUES (default, sign_id, -1, phonographic) RETURNING values.value_id INTO add_value.value_id;
  INSERT INTO value_variants VALUES (default, value_id, value) RETURNING value_variants.value_variant_id INTO add_value.value_variant_id;
  UPDATE values SET main_variant_id = value_variant_id WHERE values.value_id = add_value.value_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_value (
  sign text, 
  value text,
  phonographic boolean DEFAULT NULL,
  value_id INOUT integer DEFAULT NULL,
  value_variant_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
  sign_id integer;
  BEGIN
  SELECT allomorphs.sign_id INTO sign_id FROM sign_variants_composition JOIN allomorphs USING (allomorph_id) WHERE graphemes = sign AND sign_variants_composition.specific;
  CALL add_value(sign_id, value, phonographic, value_id, value_variant_id);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allograph (
  grapheme_id integer,
  glyph_id integer,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allograph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO allographs VALUES (default, grapheme_id, glyph_id, variant_type, specific) RETURNING allographs.allograph_id INTO allograph_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allograph (
  grapheme text,
  glyph text,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allograph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    grapheme_id integer;
    glyph_id integer;
  BEGIN
  SELECT graphemes.grapheme_id INTO grapheme_id FROM graphemes WHERE graphemes.grapheme = add_allograph.grapheme;
  SELECT glyphs.glyph_id INTO glyph_id FROM glyphs WHERE glyphs.glyph = add_allograph.glyph;
  CALL add_allograph(grapheme_id, glyph_id, variant_type, specific, allograph_id);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_default_grapheme (
  v_grapheme text,
  v_grapheme_id INOUT integer DEFAULT NULL,
  v_glyph_id INOUT integer DEFAULT NULL,
  v_allograph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO glyphs(glyph) VALUES (v_grapheme) RETURNING glyph_id INTO v_glyph_id;
  INSERT INTO graphemes(grapheme) VALUES (v_grapheme) RETURNING grapheme_id INTO v_grapheme_id;
  CALL add_allograph(v_grapheme_id, v_glyph_id, 'default', true, v_allograph_id);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allomorph (
  sign_id integer,
  graphemes text,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allomorph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO allomorphs VALUES (default, sign_id, variant_type, specific) RETURNING allomorphs.allomorph_id INTO allomorph_id;
  INSERT INTO allomorph_components
    SELECT
        allomorph_id,
        pos,
        grapheme_ids[1]
    FROM
        LATERAL split_glyphs(graphemes) WITH ORDINALITY a(grapheme_identifier, pos)
        LEFT JOIN sign_map ON identifier = grapheme_identifier AND array_length(grapheme_ids, 1) = 1;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allomorph (
  sign text, 
  graphemes text,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allomorph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
  sign_id integer;
  BEGIN
  SELECT allomorphs.sign_id INTO sign_id FROM sign_variants_composition JOIN allomorphs USING (allomorph_id) WHERE sign_variants_composition.graphemes = sign AND sign_variants_composition.specific;
  CALL add_allomorph(sign_id, graphemes, variant_type, specific, allomorph_id);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_sign (
  graphemes text,
  sign_id INOUT integer DEFAULT NULL,
  allomorph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO signs VALUES (default) RETURNING signs.sign_id INTO sign_id;
  CALL add_allomorph(sign_id, graphemes, 'default', TRUE, allomorph_id);
  END;
$BODY$;


CREATE OR REPLACE PROCEDURE delete_value (
  value_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    DELETE FROM value_variants WHERE value_variants.value_id = delete_value.value_id;
    DELETE FROM values WHERE values.value_id = delete_value.value_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE delete_allomorph (
    allomorph_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    DELETE FROM sign_variants WHERE sign_variants.allomorph_id = delete_allomorph.allomorph_id;
    DELETE FROM allomorph_components WHERE allomorph_components.allomorph_id = delete_allomorph.allomorph_id;
    DELETE FROM allomorphs WHERE allomorphs.allomorph_id = delete_allomorph.allomorph_id;
  END;
$BODY$;


CREATE OR REPLACE PROCEDURE delete_grapheme (
    grapheme_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    DELETE FROM allographs WHERE allographs.grapheme_id = delete_grapheme.grapheme_id;
    DELETE FROM graphemes WHERE graphemes.grapheme_id = delete_grapheme.grapheme_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE delete_sign (
  sign_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    id integer;
  BEGIN
    FOR id IN SELECT value_id FROM values WHERE values.sign_id = delete_sign.sign_id LOOP
        CALL delete_value(id);
    END LOOP;
    FOR id IN SELECT allomorph_id FROM allomorphs WHERE allomorphs.sign_id = delete_sign.sign_id LOOP
        CALL delete_allomorph(id);
    END LOOP;
    DELETE FROM signs WHERE signs.sign_id = delete_sign.sign_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE merge_values (
  value_id_1 integer, 
  value_id_2 integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    same_sign bool;
  BEGIN
    SELECT a.sign_id = b.sign_id INTO same_sign FROM (SELECT sign_id FROM values WHERE value_id = value_id_1) a, (SELECT sign_id FROM values WHERE value_id = value_id_2) b; 
    ASSERT same_sign;
    UPDATE value_variants SET value_id = value_id_1 WHERE value_id = value_id_2;
    DELETE FROM values WHERE value_id = value_id_2;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE merge_signs (
  sign_id_1 integer, 
  sign_id_2 integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    value_id integer;
  BEGIN
    FOR value_id IN 
        WITH value_list AS (
            SELECT * FROM value_variants JOIN values USING (value_id)
        )
        SELECT 
            a.value_id
        FROM value_list a 
            JOIN value_list b ON replace(a.value, 'x', '') = regexp_replace(b.value, '[0-9x]+$', '')
        WHERE 
            a.value ~ 'x' AND a.sign_id = sign_id_2 AND b.sign_id = sign_id_1
    LOOP
        CALL delete_value(value_id);
    END LOOP;
    FOR value_id IN 
        WITH value_list AS (
            SELECT * FROM value_variants JOIN values USING (value_id)
        )
        SELECT 
            a.value_id
        FROM value_list a 
            JOIN value_list b ON replace(a.value, 'x', '') = regexp_replace(b.value, '[0-9x]+$', '')
        WHERE 
            a.value ~ 'x' AND a.sign_id = sign_id_1 AND b.sign_id = sign_id_2
    LOOP
        CALL delete_value(value_id);
    END LOOP;
    UPDATE values SET sign_id = sign_id_1 where sign_id = sign_id_2;
    UPDATE allomorphs SET variant_type = 'nondefault' where sign_id = sign_id_2 AND variant_type = 'default';
    UPDATE allomorphs SET sign_id = sign_id_1 where sign_id = sign_id_2;
    DELETE FROM signs WHERE sign_id = sign_id_2;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE make_glyph_value (
    value_id integer,
    value_id_new integer
)
LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    INSERT INTO glyph_values 
        SELECT 
            value, 
            value_id_new, 
            glyph_ids 
        FROM 
            value_variants 
            JOIN values USING (value_id) 
            JOIN allomorphs USING (sign_id) 
            JOIN sign_variants_composition USING (allomorph_id)
        WHERE
            values.value_id = make_glyph_value.value_id AND 
            value !~ 'x' AND
            sign_variants_composition.variant_type = 'default';
    CALL delete_value(value_id);
END;
$BODY$;


CREATE OR REPLACE PROCEDURE make_glyph_value (
    value text,
    value_new text
)
LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    value_id integer;
    value_id_new integer;
  BEGIN
    SELECT value_variants.value_id INTO value_id FROM value_variants WHERE value_variants.value = make_glyph_value.value;
    SELECT value_variants.value_id INTO value_id_new FROM value_variants WHERE value_variants.value = make_glyph_value.value_new;
    CALL make_glyph_value(value_id, value_id_new);
END;
$BODY$;