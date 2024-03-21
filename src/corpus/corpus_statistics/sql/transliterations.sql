CREATE TABLE texts_transliteration_count (
    text_id integer PRIMARY KEY,
    count integer NOT NULL
);


CREATE OR REPLACE VIEW texts_transliteration_count_view AS
SELECT
    text_id,
    count(*)
FROM
    @extschema:cuneiform_corpus@.transliterations
GROUP BY 
    text_id;


CREATE OR REPLACE FUNCTION texts_transliteration_count_transliterations_trigger_fun ()
    RETURNS trigger 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    IF NOT OLD IS NULL THEN
        DELETE FROM @extschema@.texts_transliteration_count WHERE text_id = (OLD).text_id;
        INSERT INTO @extschema@.texts_transliteration_count SELECT * FROM @extschema@.texts_transliteration_count_view WHERE text_id = (OLD).text_id;
    END IF;
    IF NOT NEW IS NULL THEN
        DELETE FROM @extschema@.texts_transliteration_count WHERE text_id = (NEW).text_id;
        INSERT INTO @extschema@.texts_transliteration_count SELECT * FROM @extschema@.texts_transliteration_count_view WHERE text_id = (NEW).text_id;
    END IF;
    RETURN NULL;
END;
$BODY$;


CREATE TRIGGER texts_transliteration_count_transliterations_trigger
  AFTER UPDATE OF text_id OR INSERT OR DELETE ON @extschema:cuneiform_corpus@.transliterations
  FOR EACH ROW
  EXECUTE FUNCTION texts_transliteration_count_transliterations_trigger_fun();


INSERT INTO texts_transliteration_count SELECT * FROM texts_transliteration_count_view;