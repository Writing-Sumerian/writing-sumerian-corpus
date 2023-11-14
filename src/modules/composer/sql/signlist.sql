CREATE TABLE sign_variants_composed (
    sign_variant_id integer PRIMARY KEY REFERENCES sign_variants (sign_variant_id) DEFERRABLE INITIALLY DEFERRED,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY DEFERRED,
    variant_type sign_variant_type NOT NULL,
    length integer NOT NULL,
    graphemes_code text NOT NULL,
    graphemes_html text NOT NULL,
    glyphs_code text NOT NULL,
    glyphs_html text NOT NULL
);

CREATE TABLE values_composed (
    value_id integer REFERENCES values (value_id) DEFERRABLE INITIALLY DEFERRED,
    sign_variant_id integer REFERENCES sign_variants (sign_variant_id) DEFERRABLE INITIALLY DEFERRED,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY DEFERRED,
    value_code text NOT NULL,
    value_html text NOT NULL,
    PRIMARY KEY (value_id, sign_variant_id)
);

CREATE TABLE signs_composed (
    sign_variant_id integer PRIMARY KEY REFERENCES sign_variants (sign_variant_id) DEFERRABLE INITIALLY DEFERRED,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY DEFERRED,
    sign_code text,
    sign_html text
);


CREATE VIEW value_variants_composed AS
SELECT
    value_variant_id,
    value_id,
    sign_id,
    value_variant_id = main_variant_id AS main,
    value AS value_code,
    regexp_replace(value, '(?<=[^0-9x])([0-9x]+)$', '<span class=''index''>\1</span>') AS value_html
FROM
    value_variants
    LEFT JOIN values USING (value_id);


CREATE VIEW sign_specs_composed AS
SELECT
    sign_variant_id,
    sign_id,
    variant_type,
    CASE 
        WHEN variant_type = 'default' THEN '(' || graphemes_code || ')'
        WHEN variant_type = 'nondefault' THEN '(' || glyphs_code || ')' 
        ELSE '!(' || glyphs_code || ')' 
    END AS spec_code,
    CASE 
        WHEN variant_type = 'default' THEN '<span class=''signspec''>' || graphemes_html || '</span>'
        WHEN variant_type = 'nondefault' THEN '<span class=''signspec''>' || glyphs_html || '</span>' 
        ELSE '<span class=''critic''>!</span><span class=''signspec''>' || glyphs_html || '</span>'
    END AS spec_html
FROM
    sign_variants_composed;


-- sign variants

CREATE VIEW sign_variants_composed_view AS
SELECT
    sign_variant_id,
    sign_id,
    sign_variants.variant_type,
    count(*) AS length,
    string_agg(grapheme, '.' ORDER BY ord) AS graphemes_code,
    string_agg(grapheme_html, '.' ORDER BY ord) AS graphemes_html,
    string_agg(glyph, '.' ORDER BY ord) AS glyphs_code,
    string_agg(glyph_html, '.' ORDER BY ord) AS glyphs_html
FROM
    sign_variants
    LEFT JOIN LATERAL unnest(allograph_ids) WITH ORDINALITY AS a(allograph_id, ord) ON TRUE
    LEFT JOIN allographs USING (allograph_id)
    LEFT JOIN glyphs USING (glyph_id)
    LEFT JOIN graphemes USING (grapheme_id)
    LEFT JOIN LATERAL compose_sign_html(parse_sign(glyph)) AS c(glyph_html) ON TRUE
    LEFT JOIN LATERAL compose_sign_html(parse_sign(grapheme)) AS b(grapheme_html) ON TRUE
GROUP BY
    sign_variant_id,
    sign_id,
    sign_variants.variant_type;

INSERT INTO sign_variants_composed SELECT * FROM sign_variants_composed_view;


CREATE OR REPLACE FUNCTION upsert_sign_variants_composed (v_sign_variant_id integer)
    RETURNS void
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    INSERT INTO sign_variants_composed
    SELECT * FROM sign_variants_composed_view WHERE sign_variant_id = v_sign_variant_id
    ON CONFLICT (sign_variant_id) DO UPDATE SET 
        sign_id = EXCLUDED.sign_id,
        variant_type = EXCLUDED.variant_type,
        length = EXCLUDED.length,
        graphemes_code = EXCLUDED.graphemes_code,
        graphemes_html = EXCLUDED.graphemes_html,
        glyphs_code = EXCLUDED.glyphs_code,
        glyphs_html = EXCLUDED.glyphs_html;
END;
$BODY$;


CREATE FUNCTION sign_variants_composed_sign_variants_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM sign_variants_composed WHERE sign_variant_id = (OLD).sign_variant_id;
    ELSE
        PERFORM upsert_sign_variants_composed((NEW).sign_variant_id);
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION sign_variants_composed_allographs_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    PERFORM upsert_sign_variants_composed(sign_variant_id) FROM sign_variants WHERE (NEW).allograph_id = ANY(allograph_ids);
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION sign_variants_composed_graphemes_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    PERFORM upsert_sign_variants_composed(sign_variant_id) FROM sign_variants_composition WHERE (NEW).grapheme_id = ANY(grapheme_ids);
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION sign_variants_composed_glyphs_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    PERFORM upsert_sign_variants_composed(sign_variant_id) FROM sign_variants_composition WHERE (NEW).glyph_id = ANY(glyph_ids);
    RETURN NULL;
END;
$BODY$;

CREATE TRIGGER sign_variants_composed_sign_variants_trigger
  AFTER INSERT OR DELETE OR UPDATE OF sign_id, allograph_ids, variant_type ON sign_variants 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_sign_variants_trigger_fun();

CREATE TRIGGER sign_variants_composed_allographs_trigger
  AFTER UPDATE OF grapheme_id, glyph_id ON allographs 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_allographs_trigger_fun();

CREATE TRIGGER sign_variants_composed_graphemes_trigger
  AFTER UPDATE OF grapheme ON graphemes 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_graphemes_trigger_fun();

CREATE TRIGGER sign_variants_composed_glyphs_trigger
  AFTER UPDATE OF glyph ON glyphs 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_glyphs_trigger_fun();



-- signs

CREATE VIEW signs_composed_view AS
WITH a AS (
    SELECT
        sign_id,
        CASE
            WHEN graphemes_code ~ '\.' THEN '|' || graphemes_code || '|'
            ELSE graphemes_code
        END AS sign_code,
        '<span class=''unknown_value''>' || graphemes_html || '</span>' AS sign_html
    FROM
        sign_variants_composed
    WHERE
        variant_type = 'default'
)
SELECT
    sign_variant_id,
    sign_id,
    sign_code || CASE WHEN variant_type != 'default' THEN spec_code ELSE '' END AS sign_code,
    sign_html|| CASE WHEN variant_type != 'default' THEN spec_html ELSE '' END AS sign_html
FROM
    sign_specs_composed
    LEFT JOIN a USING (sign_id);

INSERT INTO signs_composed SELECT * FROM signs_composed_view;


CREATE FUNCTION signs_composed_sign_variants_composed_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM signs_composed WHERE sign_variant_id = (OLD).sign_variant_id;
    END IF;

    INSERT INTO signs_composed
    SELECT * FROM signs_composed_view WHERE sign_id = (OLD).sign_id OR sign_id = (NEW).sign_id
    ON CONFLICT (sign_variant_id) DO UPDATE SET 
        sign_id = EXCLUDED.sign_id,
        sign_code = EXCLUDED.sign_code,
        sign_html = EXCLUDED.sign_html;

    RETURN NULL;
END;
$BODY$;

CREATE OR REPLACE FUNCTION signs_composed_simple_sign_variants_composed_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    UPDATE signs_composed SET 
        sign_code = signs_composed_view.sign_code,
        sign_html = signs_composed_view.sign_html
    FROM
        signs_composed_view
    WHERE
        signs_composed.sign_variant_id = (NEW).sign_variant_id
        AND signs_composed_view.sign_variant_id = (NEW).sign_variant_id;
    RETURN NULL;
END;
$BODY$;

CREATE TRIGGER signs_composed_sign_variants_composed_trigger
  AFTER INSERT OR DELETE OR UPDATE OF sign_id, variant_type ON sign_variants_composed 
  FOR EACH ROW
  EXECUTE FUNCTION signs_composed_sign_variants_composed_trigger_fun();

CREATE TRIGGER signs_composed_simple_sign_variants_composed_trigger
  AFTER UPDATE OF graphemes_code, graphemes_html, glyphs_code, glyphs_html ON sign_variants_composed 
  FOR EACH ROW
  EXECUTE FUNCTION signs_composed_simple_sign_variants_composed_trigger_fun();



-- values

CREATE VIEW values_composed_view AS
SELECT
    value_id,
    sign_variant_id,
    sign_id,
    value_code || CASE WHEN variant_type != 'default' OR value_code ~ 'x$' THEN spec_code ELSE '' END AS value_code,
    value_html|| CASE WHEN variant_type != 'default' OR value_code ~ 'x$' THEN spec_html ELSE '' END AS value_html
FROM
    value_variants_composed
    LEFT JOIN sign_specs_composed USING (sign_id)
WHERE
    main;

INSERT INTO values_composed SELECT * FROM values_composed_view;


CREATE OR REPLACE FUNCTION values_composed_sign_variants_composed_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM values_composed WHERE sign_variant_id = (OLD).sign_variant_id;
    ELSE
        INSERT INTO values_composed
        SELECT * FROM values_composed_view WHERE sign_variant_id = (NEW).sign_variant_id
        ON CONFLICT (value_id, sign_variant_id) DO UPDATE SET 
            sign_id = EXCLUDED.sign_id,
            value_code = EXCLUDED.value_code,
            value_html = EXCLUDED.value_html;
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE OR REPLACE FUNCTION values_composed_values_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM values_composed WHERE value_id = (OLD).value_id;
    ELSE
        INSERT INTO values_composed
        SELECT * FROM values_composed_view WHERE value_id = (NEW).value_id
        ON CONFLICT (value_id, sign_variant_id) DO UPDATE SET 
            sign_id = EXCLUDED.sign_id,
            value_code = EXCLUDED.value_code,
            value_html = EXCLUDED.value_html;
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE OR REPLACE FUNCTION values_composed_value_variants_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
DECLARE
    v_main boolean;
BEGIN
    SELECT main INTO v_main FROM value_variants_composed WHERE value_variant_id = (NEW).value_variant_id;
    IF v_main THEN
        UPDATE values_composed SET
            value_code = values_composed_view.value_code,
            value_html = values_composed_view.value_html
        FROM
            values_composed_view
        WHERE
            values_composed.value_id = (NEW).value_id
            AND values_composed_view.value_id = (NEW).value_id
            AND values_composed.sign_variant_id = values_composed_view.sign_variant_id;
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE TRIGGER values_composed_sign_variants_composed_trigger
  AFTER INSERT OR DELETE OR UPDATE ON sign_variants_composed 
  FOR EACH ROW
  EXECUTE FUNCTION values_composed_sign_variants_composed_trigger_fun();

CREATE TRIGGER values_composed_values_trigger
  AFTER INSERT OR DELETE OR UPDATE ON values 
  FOR EACH ROW
  EXECUTE FUNCTION values_composed_values_trigger_fun();

CREATE TRIGGER values_composed_value_variants_trigger
  AFTER UPDATE ON value_variants 
  FOR EACH ROW
  EXECUTE FUNCTION values_composed_value_variants_trigger_fun();


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