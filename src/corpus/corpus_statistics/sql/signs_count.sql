CREATE TABLE texts_values_count (
    text_id integer,
    value_id integer,
    count integer NOT NULL,
    PRIMARY KEY (text_id, value_id)
);

CREATE TABLE texts_sign_variants_count (
    text_id integer,
    sign_variant_id integer,
    count integer NOT NULL,
    PRIMARY KEY (text_id, sign_variant_id)
);


CREATE OR REPLACE VIEW texts_values_count_view AS 
SELECT
    text_id,
    value_id,
    count(*)
FROM
    corpus
    JOIN transliterations USING (transliteration_id)
WHERE
    value_id IS NOT NULL
GROUP BY
    text_id,
    value_id;

CREATE OR REPLACE VIEW texts_sign_variants_count_view AS 
SELECT
    text_id,
    sign_variant_id,
    count(*)
FROM
    corpus
    JOIN transliterations USING (transliteration_id)
WHERE
    sign_variant_id IS NOT NULL
GROUP BY
    text_id,
    sign_variant_id;


CREATE OR REPLACE FUNCTION texts_values_count_corpus_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    IF NOT OLD IS NULL THEN
        UPDATE texts_values_count SET count = count-1 
        FROM 
            transliterations 
        WHERE 
            texts_values_count.text_id = transliterations.text_id
            AND transliterations.transliteration_id = (OLD).transliteration_id
            AND texts_values_count.value_id = (OLD).value_id;
        DELETE FROM texts_values_count USING transliterations 
        WHERE 
            texts_values_count.text_id = transliterations.text_id
            AND transliterations.transliteration_id = (OLD).transliteration_id
            AND count = 0;
    END IF;
    IF NOT NEW IS NULL AND NOT (NEW).value_id IS NULL THEN
        INSERT INTO texts_values_count 
        SELECT
            text_id,
            (NEW).value_id,
            1
        FROM
            transliterations
        WHERE
            transliteration_id = (NEW).transliteration_id
        ON CONFLICT (text_id, value_id) DO UPDATE
        SET count = texts_values_count.count+1;
    END IF;
    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION texts_sign_variants_count_corpus_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    IF NOT OLD IS NULL THEN
        UPDATE texts_sign_variants_count SET count = count-1 
        FROM 
            transliterations 
        WHERE 
            texts_sign_variants_count.text_id = transliterations.text_id
            AND transliterations.transliteration_id = (OLD).transliteration_id
            AND texts_sign_variants_count.sign_variant_id = (OLD).sign_variant_id;
        DELETE FROM texts_sign_variants_count USING transliterations 
        WHERE 
            texts_sign_variants_count.text_id = transliterations.text_id
            AND transliterations.transliteration_id = (OLD).transliteration_id
            AND count = 0;
    END IF;
    IF NOT NEW IS NULL AND NOT (NEW).sign_variant_id IS NULL THEN
        INSERT INTO texts_sign_variants_count 
        SELECT
            text_id,
            (NEW).sign_variant_id,
            1
        FROM
            transliterations
        WHERE
            transliteration_id = (NEW).transliteration_id
        ON CONFLICT (text_id, sign_variant_id) DO UPDATE
        SET count = texts_sign_variants_count.count+1;
    END IF;
    RETURN NULL;
END;
$BODY$;


CREATE OR REPLACE FUNCTION texts_values_sign_variants_count_transliterations_trigger_fun () 
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    IF (OLD).text_id = (NEW).text_id THEN
        RETURN null;
    END IF;
    DELETE FROM texts_values_count WHERE text_id = (OLD).text_id OR text_id = (NEW).text_id;
    DELETE FROM texts_sign_variants_count WHERE text_id = (OLD).text_id OR text_id = (NEW).text_id;
    INSERT INTO texts_values_count SELECT * FROM texts_values_count_view WHERE text_id = (OLD).text_id OR text_id = (NEW).text_id;
    INSERT INTO texts_sign_variants_count SELECT * FROM texts_sign_variants_count_view WHERE text_id = (OLD).text_id OR text_id = (NEW).text_id;
    RETURN NULL;
END;
$BODY$;

CREATE TRIGGER texts_values_count_corpus_trigger
  AFTER UPDATE OF value_id OR INSERT OR DELETE ON corpus
  FOR EACH ROW
  EXECUTE FUNCTION texts_values_count_corpus_trigger_fun();

CREATE TRIGGER texts_sign_variants_count_corpus_trigger
  AFTER UPDATE OF sign_variant_id OR INSERT OR DELETE ON corpus
  FOR EACH ROW
  EXECUTE FUNCTION texts_sign_variants_count_corpus_trigger_fun();

CREATE TRIGGER texts_values_sign_variants_count_transliterations_trigger
  AFTER UPDATE OF text_id ON transliterations
  FOR EACH ROW
  EXECUTE FUNCTION texts_values_sign_variants_count_transliterations_trigger_fun();

INSERT INTO texts_values_count SELECT * FROM texts_values_count_view;
INSERT INTO texts_sign_variants_count SELECT * FROM texts_sign_variants_count_view;