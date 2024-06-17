CREATE TABLE values_present (
    value_id integer,
    period_id integer,
    provenience_id integer,
    genre_id integer,
    object_id integer,
    count integer,
    count_norm real
);

CREATE TABLE sign_variants_present (
    sign_variant_id integer,
    period_id integer,
    provenience_id integer,
    genre_id integer,
    object_id integer,
    count integer,
    count_norm real
);

CREATE OR REPLACE VIEW values_present_view AS
SELECT 
    value_id,
    period_id,
    provenience_id,
    genre_id,
    object_id,
    sum(texts_values_count.count) AS count,
    sum(texts_values_count.count::real/texts_transliteration_count.count) AS count_norm
FROM    
    texts_values_count
    JOIN texts_transliteration_count USING (text_id)
    JOIN @extschema:cuneiform_corpus@.texts USING (text_id)
GROUP BY
    value_id,
    period_id,
    provenience_id,
    genre_id,
    object_id;


CREATE OR REPLACE VIEW sign_variants_present_view AS
SELECT 
    sign_variant_id,
    period_id,
    provenience_id,
    genre_id,
    object_id,
    sum(texts_sign_variants_count.count) AS count,
    sum(texts_sign_variants_count.count::real/texts_transliteration_count.count) AS count_norm
FROM    
    texts_sign_variants_count
    JOIN texts_transliteration_count USING (text_id)
    JOIN @extschema:cuneiform_corpus@.texts USING (text_id)
GROUP BY
    sign_variant_id,
    period_id,
    provenience_id,
    genre_id,
    object_id;


CREATE OR REPLACE FUNCTION values_present_texts_values_count_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    DELETE FROM @extschema@.values_present 
    USING @extschema:cuneiform_corpus@.texts 
    WHERE 
        ((texts.text_id = (OLD).text_id AND value_id = (OLD).value_id) 
        OR (texts.text_id = (NEW).text_id AND value_id = (NEW).value_id))
        AND values_present.period_id = texts.period_id
        AND values_present.provenience_id = texts.provenience_id
        AND values_present.genre_id = texts.genre_id
        AND values_present.object_id = texts.object_id;
    INSERT INTO @extschema@.values_present
    SELECT DISTINCT
        values_present_view.* 
    FROM 
        @extschema@.values_present_view
        JOIN @extschema:cuneiform_corpus@.texts USING (period_id, provenience_id, genre_id, object_id)
    WHERE 
        (texts.text_id = (OLD).text_id AND value_id = (OLD).value_id) 
        OR (texts.text_id = (NEW).text_id AND value_id = (NEW).value_id);
    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION sign_variants_present_texts_sign_variants_count_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    DELETE FROM @extschema@.sign_variants_present 
    USING @extschema:cuneiform_corpus@.texts 
    WHERE 
        ((texts.text_id = (OLD).text_id AND sign_variant_id = (OLD).sign_variant_id) 
        OR (texts.text_id = (NEW).text_id AND sign_variant_id = (NEW).sign_variant_id))
        AND sign_variants_present.period_id = texts.period_id
        AND sign_variants_present.provenience_id = texts.provenience_id
        AND sign_variants_present.genre_id = texts.genre_id
        AND sign_variants_present.object_id = texts.object_id;
    INSERT INTO @extschema@.sign_variants_present
    SELECT DISTINCT
        sign_variants_present_view.* 
    FROM 
        @extschema@.sign_variants_present_view
        JOIN @extschema:cuneiform_corpus@.texts USING (period_id, provenience_id, genre_id, object_id)
    WHERE 
        (texts.text_id = (OLD).text_id AND sign_variant_id = (OLD).sign_variant_id) 
        OR (texts.text_id = (NEW).text_id AND sign_variant_id = (NEW).sign_variant_id);
    
    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION values_sign_variants_present_texts_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    DELETE FROM @extschema@.values_present 
    WHERE 
        ((OLD).period_id != (NEW).period_id AND (period_id = (OLD).period_id OR period_id = (NEW).period_id))
        OR ((OLD).provenience_id != (NEW).provenience_id AND (provenience_id = (OLD).provenience_id OR provenience_id = (NEW).provenience_id))
        OR ((OLD).genre_id != (NEW).genre_id AND (genre_id = (OLD).genre_id OR genre_id = (NEW).genre_id))
        OR ((OLD).object_id != (NEW).object_id AND (object_id = (OLD).object_id OR object_id = (NEW).object_id));
    DELETE FROM @extschema@.sign_variants_present 
    WHERE 
        ((OLD).period_id != (NEW).period_id AND (period_id = (OLD).period_id OR period_id = (NEW).period_id))
        OR ((OLD).provenience_id != (NEW).provenience_id AND (provenience_id = (OLD).provenience_id OR provenience_id = (NEW).provenience_id))
        OR ((OLD).genre_id != (NEW).genre_id AND (genre_id = (OLD).genre_id OR genre_id = (NEW).genre_id))
        OR ((OLD).object_id != (NEW).object_id AND (object_id = (OLD).object_id OR object_id = (NEW).object_id));
    INSERT INTO @extschema@.values_present
    SELECT * FROM @extschema@.values_present_view
    WHERE 
        ((OLD).period_id != (NEW).period_id AND (period_id = (OLD).period_id OR period_id = (NEW).period_id))
        OR ((OLD).provenience_id != (NEW).provenience_id AND (provenience_id = (OLD).provenience_id OR provenience_id = (NEW).provenience_id))
        OR ((OLD).genre_id != (NEW).genre_id AND (genre_id = (OLD).genre_id OR genre_id = (NEW).genre_id))
        OR ((OLD).object_id != (NEW).object_id AND (object_id = (OLD).object_id OR object_id = (NEW).object_id));
    INSERT INTO @extschema@.sign_variants_present
    SELECT * FROM @extschema@.sign_variants_present_view
    WHERE 
        ((OLD).period_id != (NEW).period_id AND (period_id = (OLD).period_id OR period_id = (NEW).period_id))
        OR ((OLD).provenience_id != (NEW).provenience_id AND (provenience_id = (OLD).provenience_id OR provenience_id = (NEW).provenience_id))
        OR ((OLD).genre_id != (NEW).genre_id AND (genre_id = (OLD).genre_id OR genre_id = (NEW).genre_id))
        OR ((OLD).object_id != (NEW).object_id AND (object_id = (OLD).object_id OR object_id = (NEW).object_id));

    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION values_sign_variants_present_texts_transliteration_count_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    UPDATE @extschema@.values_present SET count_norm = values_present_view.count_norm
    FROM
         @extschema@.texts_transliteration_count
        JOIN @extschema:cuneiform_corpus@.texts USING (text_id)
        JOIN @extschema@.texts_values_count USING (text_id)
        JOIN @extschema@.values_present_view USING (value_id, period_id, provenience_id, genre_id, object_id)
    WHERE
        text_id = (NEW).text_id
        AND values_present.value_id = values_present_view.value_id
        AND values_present.period_id = values_present_view.period_id
        AND values_present.provenience_id = values_present_view.provenience_id
        AND values_present.genre_id = values_present_view.genre_id
        AND values_present.object_id = values_present_view.object_id;

    UPDATE  @extschema@.sign_variants_present SET count_norm = sign_variants_present_view.count_norm
    FROM
         @extschema@.texts_transliteration_count
        JOIN @extschema:cuneiform_corpus@.texts USING (text_id)
        JOIN @extschema@.texts_sign_variants_count USING (text_id)
        JOIN @extschema@.sign_variants_present_view USING (sign_variant_id, period_id, provenience_id, genre_id, object_id)
    WHERE
        text_id = (NEW).text_id
        AND sign_variants_present.sign_variant_id = sign_variants_present_view.sign_variant_id
        AND sign_variants_present.period_id = sign_variants_present_view.period_id
        AND sign_variants_present.provenience_id = sign_variants_present_view.provenience_id
        AND sign_variants_present.genre_id = sign_variants_present_view.genre_id
        AND sign_variants_present.object_id = sign_variants_present_view.object_id;

    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION values_sign_variants_present_transliterations_before_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    DROP TRIGGER values_present_texts_values_count_trigger ON @extschema@.texts_values_count;
    DROP TRIGGER sign_variants_present_texts_sign_variants_count_trigger ON @extschema@.texts_sign_variants_count;
    RETURN NULL;
END;
$BODY$;

CREATE OR REPLACE FUNCTION values_sign_variants_present_transliterations_after_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    CREATE TRIGGER values_present_texts_values_count_trigger
        AFTER UPDATE OR INSERT OR DELETE ON @extschema@.texts_values_count
        FOR EACH ROW
        EXECUTE FUNCTION @extschema@.values_present_texts_values_count_trigger_fun();
    CREATE TRIGGER sign_variants_present_texts_sign_variants_count_trigger
        AFTER UPDATE OR INSERT OR DELETE ON @extschema@.texts_sign_variants_count
        FOR EACH ROW
        EXECUTE FUNCTION @extschema@.sign_variants_present_texts_sign_variants_count_trigger_fun();
    RETURN NULL;
END;
$BODY$;


CREATE TRIGGER values_present_texts_values_count_trigger
  AFTER UPDATE OR INSERT OR DELETE ON texts_values_count
  FOR EACH ROW
  EXECUTE FUNCTION values_present_texts_values_count_trigger_fun();

CREATE TRIGGER sign_variants_present_texts_sign_variants_count_trigger
  AFTER UPDATE OR INSERT OR DELETE ON texts_sign_variants_count
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_present_texts_sign_variants_count_trigger_fun();

CREATE TRIGGER values_sign_variants_present_texts_trigger
  AFTER UPDATE OF period_id, provenience_id, genre_id, object_id ON @extschema:cuneiform_corpus@.texts
  FOR EACH ROW
  EXECUTE FUNCTION values_sign_variants_present_texts_trigger_fun();

CREATE TRIGGER values_sign_variants_present_texts_transliteration_count_trigger
  AFTER UPDATE OF count ON texts_transliteration_count
  FOR EACH ROW
  EXECUTE FUNCTION values_sign_variants_present_texts_transliteration_count_trigger_fun();

CREATE TRIGGER values_sign_variants_present_transliterations_before_trigger
    BEFORE UPDATE OF text_id ON @extschema:cuneiform_corpus@.transliterations
    FOR EACH STATEMENT
    EXECUTE FUNCTION values_sign_variants_present_transliterations_before_trigger_fun();

CREATE TRIGGER values_sign_variants_present_transliterations_after_trigger
    AFTER UPDATE OF text_id ON @extschema:cuneiform_corpus@.transliterations
    FOR EACH STATEMENT
    EXECUTE FUNCTION values_sign_variants_present_transliterations_after_trigger_fun();

INSERT INTO values_present SELECT * FROM values_present_view;
INSERT INTO sign_variants_present SELECT * FROM sign_variants_present_view;

CREATE INDEX ON texts_values_count (value_id);
CREATE INDEX ON texts_sign_variants_count (sign_variant_id);