CREATE TABLE values_present (
    value_id integer,
    period_id integer,
    provenience_id integer,
    genre_id integer,
    object_id integer,
    count integer,
    count_norm numeric,
    UNIQUE (value_id, period_id, provenience_id, genre_id, object_id)
);

CREATE TABLE sign_variants_present (
    sign_variant_id integer,
    period_id integer,
    provenience_id integer,
    genre_id integer,
    object_id integer,
    count integer,
    count_norm numeric,
    UNIQUE (sign_variant_id, period_id, provenience_id, genre_id, object_id)
);


CREATE OR REPLACE FUNCTION adjust_value_statistics (
        v_value_id integer,
        v_period_id integer,
        v_provenience_id integer,
        v_genre_id integer,
        v_object_id integer,
        v_val integer,
        v_val_norm numeric
    ) 
    RETURNS void
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
DECLARE
    zero boolean;
BEGIN
    IF v_val = 0 THEN
        RETURN;
    END IF;

    UPDATE values_present SET
        count = count + v_val,
        count_norm = count_norm + v_val_norm
    WHERE 
        value_id = v_value_id
        AND period_id IS NOT DISTINCT FROM v_period_id
        AND provenience_id IS NOT DISTINCT FROM v_provenience_id
        AND genre_id IS NOT DISTINCT FROM v_genre_id
        AND object_id IS NOT DISTINCT FROM v_object_id
    RETURNING
        count = 0 INTO zero;

    IF zero THEN
        DELETE FROM values_present 
        WHERE 
            value_id = v_value_id
            AND period_id IS NOT DISTINCT FROM v_period_id
            AND provenience_id IS NOT DISTINCT FROM v_provenience_id
            AND genre_id IS NOT DISTINCT FROM v_genre_id
            AND object_id IS NOT DISTINCT FROM v_object_id;
    ELSIF zero IS NULL THEN
        INSERT INTO values_present VALUES (v_value_id, v_period_id, v_provenience_id, v_genre_id, v_object_id, v_val, v_val_norm);
    END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION adjust_sign_variant_statistics (
        v_sign_variant_id integer,
        v_period_id integer,
        v_provenience_id integer,
        v_genre_id integer,
        v_object_id integer,
        v_val integer,
        v_val_norm numeric
    ) 
    RETURNS void
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
DECLARE
    zero boolean;
BEGIN
    UPDATE sign_variants_present SET
        count = count + v_val,
        count_norm = count_norm + v_val_norm
    WHERE 
        sign_variant_id = v_sign_variant_id
        AND period_id IS NOT DISTINCT FROM v_period_id
        AND provenience_id IS NOT DISTINCT FROM v_provenience_id
        AND genre_id IS NOT DISTINCT FROM v_genre_id
        AND object_id IS NOT DISTINCT FROM v_object_id
    RETURNING
        count = 0 INTO zero;

    IF zero THEN
        DELETE FROM sign_variants_present 
        WHERE 
            sign_variant_id = v_sign_variant_id
            AND period_id IS NOT DISTINCT FROM v_period_id
            AND provenience_id IS NOT DISTINCT FROM v_provenience_id
            AND genre_id IS NOT DISTINCT FROM v_genre_id
            AND object_id IS NOT DISTINCT FROM v_object_id;
    ELSIF zero IS NULL THEN
        INSERT INTO sign_variants_present VALUES (v_sign_variant_id, v_period_id, v_provenience_id, v_genre_id, v_object_id, v_val, v_val_norm);
    END IF;
    
END;
$BODY$;


CREATE OR REPLACE FUNCTION values_present_corpus_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    IF NOT OLD IS NULL THEN
        PERFORM adjust_value_statistics((OLD).value_id, min(period_id), min(provenience_id), min(genre_id), min(object_id), -1, -1.0/count(*))
            FROM transliterations a JOIN texts USING (text_id) JOIN transliterations b USING (text_id) WHERE a.transliteration_id = (OLD).transliteration_id;
    END IF;
    IF NOT NEW IS NULL THEN
        PERFORM adjust_value_statistics((NEW).value_id, min(period_id), min(provenience_id), min(genre_id), min(object_id), 1, 1.0/count(*))
            FROM transliterations a JOIN texts USING (text_id) JOIN transliterations b USING (text_id) WHERE a.transliteration_id = (NEW).transliteration_id;
    END IF;
    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION sign_variants_present_corpus_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    IF NOT OLD IS NULL THEN
        PERFORM adjust_sign_variant_statistics((OLD).sign_variant_id, min(period_id), min(provenience_id), min(genre_id), min(object_id), -1, -1.0/count(*))
            FROM transliterations a JOIN texts USING (text_id) JOIN transliterations b USING (text_id) WHERE a.transliteration_id = (OLD).transliteration_id;
    END IF;
    IF NOT NEW IS NULL THEN
        PERFORM adjust_sign_variant_statistics((NEW).sign_variant_id, min(period_id), min(provenience_id), min(genre_id), min(object_id), 1, 1.0/count(*))
            FROM transliterations a JOIN texts USING (text_id) JOIN transliterations b USING (text_id) WHERE a.transliteration_id = (NEW).transliteration_id;
    END IF;
    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION signs_present_transliterations_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
DECLARE 
    v_transliteration_ids integer[];
BEGIN
    IF (OLD).text_id = (NEW).text_id THEN
        RETURN null;
    END IF;

    SELECT array_agg(transliteration_id) INTO v_transliteration_ids FROM (SELECT transliteration_id FROM transliterations WHERE text_id = (OLD).text_id UNION ALL SELECT (OLD).transliteration_id) _;

    PERFORM adjust_value_statistics(
            value_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            -count(*)::integer, 
            -count(*)::numeric/(cardinality(v_transliteration_ids))
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = ANY(v_transliteration_ids)
        AND texts.text_id = (OLD).text_id
    GROUP BY value_id, period_id, provenience_id, genre_id, object_id;

    PERFORM adjust_value_statistics(
            value_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            count(*)::integer,
            count(*)::numeric/(cardinality(v_transliteration_ids)-1)
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = ANY(v_transliteration_ids)
        AND corpus.transliteration_id != (OLD).transliteration_id
        AND texts.text_id = (OLD).text_id
    GROUP BY value_id, period_id, provenience_id, genre_id, object_id;

    PERFORM adjust_sign_variant_statistics(
            sign_variant_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            -count(*)::integer, 
            -count(*)::numeric/(cardinality(v_transliteration_ids))
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = ANY(v_transliteration_ids)
        AND texts.text_id = (OLD).text_id
    GROUP BY sign_variant_id, period_id, provenience_id, genre_id, object_id;

    PERFORM adjust_sign_variant_statistics(
            sign_variant_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            count(*)::integer,
            count(*)::numeric/(cardinality(v_transliteration_ids)-1)
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = ANY(v_transliteration_ids)
        AND corpus.transliteration_id != (OLD).transliteration_id
        AND texts.text_id = (OLD).text_id
    GROUP BY sign_variant_id, period_id, provenience_id, genre_id, object_id;


    SELECT array_agg(transliteration_id) INTO v_transliteration_ids FROM transliterations WHERE text_id = (NEW).text_id;

    PERFORM adjust_value_statistics(
            value_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            -count(*)::integer, 
            -count(*)::numeric/(cardinality(v_transliteration_ids-1))
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = ANY(v_transliteration_ids)
        AND corpus.transliteration_id != (NEW).transliteration_id
        AND texts.text_id = (NEW).text_id
    GROUP BY value_id, period_id, provenience_id, genre_id, object_id;

    PERFORM adjust_value_statistics(
            value_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            count(*)::integer, 
            count(*)::numeric/cardinality(v_transliteration_ids)
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = (NEW).transliteration_id
        AND texts.text_id = (NEW).text_id
    GROUP BY value_id, period_id, provenience_id, genre_id, object_id;

    PERFORM adjust_sign_variant_statistics(
            sign_variant_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            -count(*)::integer, 
            -count(*)::numeric/(cardinality(v_transliteration_ids-1))
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = ANY(v_transliteration_ids)
        AND corpus.transliteration_id != (NEW).transliteration_id
        AND texts.text_id = (NEW).text_id
    GROUP BY sign_variant_id, period_id, provenience_id, genre_id, object_id;

    PERFORM adjust_sign_variant_statistics(
            sign_variant_id, 
            period_id, 
            provenience_id, 
            genre_id, 
            object_id,
            count(*)::integer, 
            count(*)::numeric/cardinality(v_transliteration_ids)
        )
    FROM
        corpus, texts
    WHERE
        corpus.transliteration_id = (NEW).transliteration_id
        AND texts.text_id = (NEW).text_id
    GROUP BY sign_variant_id, period_id, provenience_id, genre_id, object_id;


    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION signs_present_texts_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
DECLARE 
    v_transliteration_count integer;
BEGIN
    SELECT count(*) INTO v_transliteration_count FROM transliterations a JOIN transliterations b USING (text_id) WHERE a.transliteration_id = COALESCE((OLD).text_id, (NEW).text_id);

    PERFORM adjust_value_statistics(value_id, (OLD).period_id, (OLD).provenience_id, (OLD).genre_id, (OLD).object_id, -count(*)::integer, -count(*)::numeric/v_transliteration_count)
    FROM
        corpus
        JOIN transliterations USING (transliteration_id)
    WHERE
        text_id = (OLD).text_id
    GROUP BY value_id;
    
    PERFORM adjust_value_statistics(value_id, (NEW).period_id, (NEW).provenience_id, (NEW).genre_id, (NEW).object_id, count(*)::integer, count(*)::numeric/v_transliteration_count)
    FROM
        corpus
        JOIN transliterations USING (transliteration_id)
    WHERE
        text_id = (NEW).text_id
    GROUP BY value_id;


    PERFORM adjust_sign_variant_statistics(sign_variant_id, (OLD).period_id, (OLD).provenience_id, (OLD).genre_id, (OLD).object_id, -count(*)::integer, -count(*)::numeric/v_transliteration_count)
    FROM
        corpus
        JOIN transliterations USING (transliteration_id)
    WHERE
        text_id = (OLD).text_id
    GROUP BY sign_variant_id;
    
    PERFORM adjust_sign_variant_statistics(sign_variant_id, (NEW).period_id, (NEW).provenience_id, (NEW).genre_id, (NEW).object_id, count(*)::integer, count(*)::numeric/v_transliteration_count)
    FROM
        corpus
        JOIN transliterations USING (transliteration_id)
    WHERE
        text_id = (NEW).text_id
    GROUP BY sign_variant_id;

    RETURN NULL;
END;
$BODY$;
 


CREATE VIEW values_present_view AS
SELECT 
    value_id,
    period_id,
    provenience_id,
    genre_id,
    object_id,
    count(*) AS count,
    sum(1.0/transliteration_count) AS count_norm
FROM corpus
    LEFT JOIN transliterations USING (transliteration_id)
    LEFT JOIN texts USING (text_id)
    LEFT JOIN (SELECT text_id, count(*) AS transliteration_count FROM transliterations GROUP BY text_id) _ USING (text_id)
WHERE
    value_id IS NOT NULL
GROUP BY
    value_id,
    period_id,
    provenience_id,
    genre_id,
    object_id;


CREATE VIEW sign_variants_present_view AS
SELECT DISTINCT 
  sign_variant_id,
  period_id,
  provenience_id,
  genre_id,
  object_id,
  count(*) AS count,
  sum(1.0/transliteration_count) AS count_norm
FROM corpus
  LEFT JOIN transliterations USING (transliteration_id)
  LEFT JOIN texts USING (text_id)
  LEFT JOIN (SELECT text_id, count(*) AS transliteration_count FROM transliterations GROUP BY text_id) _ USING (text_id)
GROUP BY
  sign_variant_id,
  period_id,
  provenience_id,
  genre_id,
  object_id;


CREATE TRIGGER values_present_corpus_trigger
  AFTER UPDATE OF value_id OR INSERT OR DELETE ON corpus
  FOR EACH ROW
  EXECUTE FUNCTION values_present_corpus_trigger_fun();

CREATE TRIGGER sign_variants_present_corpus_trigger
  AFTER UPDATE OF sign_variant_id OR INSERT OR DELETE ON corpus
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_present_corpus_trigger_fun();

CREATE TRIGGER signs_present_transliterations_trigger
  AFTER UPDATE OF text_id OR INSERT OR DELETE ON transliterations
  FOR EACH ROW
  EXECUTE FUNCTION signs_present_transliterations_trigger_fun();

CREATE TRIGGER signs_present_text_trigger
  AFTER UPDATE OF period_id, provenience_id, genre_id, object_id ON texts
  FOR EACH ROW
  EXECUTE FUNCTION signs_present_texts_trigger_fun();