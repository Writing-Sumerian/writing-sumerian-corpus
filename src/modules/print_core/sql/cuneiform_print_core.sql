
CREATE OR REPLACE PROCEDURE create_signlist_print (
        v_suffix text,
        v_schema text,
        v_print_value text,
        v_print_spec text,
        v_print_grapheme text,
        v_print_glyph text,
        v_print_graphemes text
    )
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN

EXECUTE format($$
    CREATE TABLE %1$I.sign_variants_%2$s (
        sign_variant_id integer PRIMARY KEY REFERENCES sign_variants (sign_variant_id) DEFERRABLE INITIALLY DEFERRED,
        sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY DEFERRED,
        variant_type sign_variant_type NOT NULL,
        length integer NOT NULL,
        graphemes_print text NOT NULL,
        glyphs_print text NOT NULL
    )
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TABLE %1$I.values_%2$s (
        value_id integer REFERENCES values (value_id) DEFERRABLE INITIALLY DEFERRED,
        sign_variant_id integer REFERENCES sign_variants (sign_variant_id) DEFERRABLE INITIALLY DEFERRED,
        sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY DEFERRED,
        value_print text NOT NULL,
        PRIMARY KEY (value_id, sign_variant_id)
    )
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TABLE %1$I.signs_%2$s (
        sign_variant_id integer PRIMARY KEY REFERENCES sign_variants (sign_variant_id) DEFERRABLE INITIALLY DEFERRED,
        sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY DEFERRED,
        sign_print text
    )
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE VIEW %1$I.value_variants_%2$s AS
    SELECT
        value_variant_id,
        value_id,
        sign_id,
        value_variant_id = main_variant_id AS main,
        value ~ 'x' AS x_value,
        %3$s(value) AS value_print
    FROM
        value_variants
        LEFT JOIN values USING (value_id)
    $$,
    v_schema,
    v_suffix,
    v_print_value);

EXECUTE format($$
    CREATE VIEW %1$I.sign_specs_%2$s AS
    SELECT
        sign_variant_id,
        sign_id,
        variant_type,
        %3$s(variant_type, graphemes_print, glyphs_print) AS spec_print
    FROM
        %1$I.sign_variants_%2$s
    $$,
    v_schema,
    v_suffix,
    v_print_spec);



-- sign variants

EXECUTE format($$
    CREATE VIEW %1$I.sign_variants_%2$s_view AS
    SELECT
        sign_variant_id,
        sign_id,
        sign_variants.variant_type,
        count(*) AS length,
        string_agg(%3$s(grapheme), '.' ORDER BY ord) AS graphemes_print,
        string_agg(%4$s(glyph), '.' ORDER BY ord) AS glyphs_print
    FROM
        sign_variants
        LEFT JOIN LATERAL unnest(allograph_ids) WITH ORDINALITY AS a(allograph_id, ord) ON TRUE
        LEFT JOIN allographs USING (allograph_id)
        LEFT JOIN glyphs USING (glyph_id)
        LEFT JOIN graphemes USING (grapheme_id)
    GROUP BY
        sign_variant_id,
        sign_id,
        sign_variants.variant_type
    $$,
    v_schema,
    v_suffix,
    v_print_grapheme,
    v_print_glyph);


EXECUTE format($$
    INSERT INTO %1$I.sign_variants_%2$s SELECT * FROM %1$I.sign_variants_%2$s_view
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE OR REPLACE FUNCTION %1$I.upsert_sign_variants_%2$s (v_sign_variant_id integer)
        RETURNS void
        VOLATILE
        LANGUAGE PLPGSQL
        AS
    $INNERBODY$
    BEGIN
        INSERT INTO %1$I.sign_variants_%2$s
        SELECT * FROM %1$I.sign_variants_%2$s_view WHERE sign_variant_id = v_sign_variant_id
        ON CONFLICT (sign_variant_id) DO UPDATE SET 
            sign_id = EXCLUDED.sign_id,
            variant_type = EXCLUDED.variant_type,
            length = EXCLUDED.length,
            graphemes_print = EXCLUDED.graphemes_print,
            glyphs_print = EXCLUDED.glyphs_print;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);


EXECUTE format($$
    CREATE FUNCTION %1$I.sign_variants_%2$s_sign_variants_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        IF NEW IS NULL THEN
            DELETE FROM %1$I.sign_variants_%2$s WHERE sign_variant_id = (OLD).sign_variant_id;
        ELSE
            PERFORM %1$I.upsert_sign_variants_%2$s((NEW).sign_variant_id);
        END IF;
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE FUNCTION %1$I.sign_variants_%2$s_allographs_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        PERFORM %1$I.upsert_sign_variants_%2$s(sign_variant_id) FROM sign_variants WHERE (NEW).allograph_id = ANY(allograph_ids);
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE FUNCTION %1$I.sign_variants_%2$s_graphemes_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        PERFORM %1$I.upsert_sign_variants_%2$s(sign_variant_id) FROM sign_variants_composition WHERE (NEW).grapheme_id = ANY(grapheme_ids);
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE FUNCTION %1$I.sign_variants_%2$s_glyphs_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        PERFORM %1$I.upsert_sign_variants_%2$s(sign_variant_id) FROM sign_variants_composition WHERE (NEW).glyph_id = ANY(glyph_ids);
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER sign_variants_%2$s_sign_variants_trigger
    AFTER INSERT OR DELETE OR UPDATE OF sign_id, allograph_ids, variant_type ON sign_variants 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.sign_variants_%2$s_sign_variants_trigger_fun()
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER sign_variants_%2$s_allographs_trigger
    AFTER UPDATE OF grapheme_id, glyph_id ON allographs 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.sign_variants_%2$s_allographs_trigger_fun()
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER sign_variants_%2$s_graphemes_trigger
    AFTER UPDATE OF grapheme ON graphemes 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.sign_variants_%2$s_graphemes_trigger_fun()
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER sign_variants_%2$s_glyphs_trigger
    AFTER UPDATE OF glyph ON glyphs 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.sign_variants_%2$s_glyphs_trigger_fun()
    $$,
    v_schema,
    v_suffix);



-- signs

EXECUTE format($$
CREATE VIEW %1$I.signs_%2$s_view AS
    WITH a AS (
        SELECT
            sign_id,
            %3$s(graphemes_print) AS sign_print
        FROM
            %1$I.sign_variants_%2$s
        WHERE
            variant_type = 'default'
    )
    SELECT
        sign_variant_id,
        sign_id,
        sign_print || CASE WHEN variant_type != 'default' THEN spec_print ELSE '' END AS sign_print
    FROM
        %1$I.sign_specs_%2$s
        LEFT JOIN a USING (sign_id)
    $$,
    v_schema,
    v_suffix,
    v_print_graphemes);

EXECUTE format($$
    INSERT INTO %1$I.signs_%2$s SELECT * FROM %1$I.signs_%2$s_view
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE FUNCTION %1$I.signs_%2$s_sign_variants_%2$s_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        IF NEW IS NULL THEN
            DELETE FROM %1$I.signs_%2$s WHERE sign_variant_id = (OLD).sign_variant_id;
        END IF;

        INSERT INTO %1$I.signs_%2$s
        SELECT * FROM %1$I.signs_%2$s_view WHERE sign_id = (OLD).sign_id OR sign_id = (NEW).sign_id
        ON CONFLICT (sign_variant_id) DO UPDATE SET 
            sign_id = EXCLUDED.sign_id,
            sign_print = EXCLUDED.sign_print;

        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE OR REPLACE FUNCTION %1$I.signs_%2$s_simple_sign_variants_%2$s_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        UPDATE %1$I.signs_%2$s SET 
            sign_print = signs_%2$s_view.sign_print
        FROM
            %1$I.signs_%2$s_view
        WHERE
            signs_%2$s.sign_variant_id = (NEW).sign_variant_id
            AND signs_%2$s_view.sign_variant_id = (NEW).sign_variant_id;
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER signs_%2$s_sign_variants_%2$s_trigger
    AFTER INSERT OR DELETE OR UPDATE OF sign_id, variant_type ON %1$I.sign_variants_%2$s 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.signs_%2$s_sign_variants_%2$s_trigger_fun()
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER signs_%2$s_simple_sign_variants_%2$s_trigger
    AFTER UPDATE OF graphemes_print, glyphs_print ON %1$I.sign_variants_%2$s 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.signs_%2$s_simple_sign_variants_%2$s_trigger_fun()
    $$,
    v_schema,
    v_suffix);



-- values

EXECUTE format($$
    CREATE VIEW %1$I.values_%2$s_view AS
    SELECT
        value_id,
        sign_variant_id,
        sign_id,
        value_print || CASE WHEN variant_type != 'default' OR x_value THEN spec_print ELSE '' END AS value_print
    FROM
        %1$I.value_variants_%2$s
        LEFT JOIN %1$I.sign_specs_%2$s USING (sign_id)
    WHERE
        main
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    INSERT INTO %1$I.values_%2$s SELECT * FROM %1$I.values_%2$s_view
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE OR REPLACE FUNCTION %1$I.values_%2$s_sign_variants_%2$s_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        IF NEW IS NULL THEN
            DELETE FROM %1$I.values_%2$s WHERE sign_variant_id = (OLD).sign_variant_id;
        ELSE
            INSERT INTO %1$I.values_%2$s
            SELECT * FROM %1$I.values_%2$s_view WHERE sign_variant_id = (NEW).sign_variant_id
            ON CONFLICT (value_id, sign_variant_id) DO UPDATE SET 
                sign_id = EXCLUDED.sign_id,
                value_print = EXCLUDED.value_print;
        END IF;
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE OR REPLACE FUNCTION %1$I.values_%2$s_values_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    BEGIN
        IF NEW IS NULL THEN
            DELETE FROM %1$I.values_%2$s WHERE value_id = (OLD).value_id;
        ELSE
            INSERT INTO %1$I.values_%2$s
            SELECT * FROM %1$I.values_%2$s_view WHERE value_id = (NEW).value_id
            ON CONFLICT (value_id, sign_variant_id) DO UPDATE SET 
                sign_id = EXCLUDED.sign_id,
                value_print = EXCLUDED.value_print;
        END IF;
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE OR REPLACE FUNCTION %1$I.values_%2$s_value_variants_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
    $INNERBODY$
    DECLARE
        v_main boolean;
    BEGIN
        SELECT main INTO v_main FROM %1$I.value_variants_%2$s WHERE value_variant_id = (NEW).value_variant_id;
        IF v_main THEN
            UPDATE %1$I.values_%2$s SET
                value_print = values_%2$s_view.value_print
            FROM
                %1$I.values_%2$s_view
            WHERE
                values_%2$s.value_id = (NEW).value_id
                AND values_%2$s_view.value_id = (NEW).value_id
                AND values_%2$s.sign_variant_id = values_%2$s_view.sign_variant_id;
        END IF;
        RETURN NULL;
    END;
    $INNERBODY$
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER values_%2$s_sign_variants_%2$s_trigger
    AFTER INSERT OR DELETE OR UPDATE ON %1$I.sign_variants_%2$s 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.values_%2$s_sign_variants_%2$s_trigger_fun()
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER values_%2$s_values_trigger
    AFTER INSERT OR DELETE OR UPDATE ON values 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.values_%2$s_values_trigger_fun()
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE TRIGGER values_%2$s_value_variants_trigger
    AFTER UPDATE ON value_variants 
    FOR EACH ROW
    EXECUTE FUNCTION %1$I.values_%2$s_value_variants_trigger_fun()
    $$,
    v_schema,
    v_suffix);

EXECUTE format($$
    CREATE VIEW %1$I.characters_%2$s AS
    SELECT
        value_id,
        sign_variant_id,
        value_print AS character_print
    FROM
        %1$I.values_%2$s
    UNION ALL
    SELECT
        NULL AS value_id,
        sign_variant_id,
        sign_print AS character_print
    FROM
        %1$I.signs_%2$s
    $$,
    v_schema,
    v_suffix);

END;
$BODY$;