CREATE TABLE blocks_display (
    transliteration_id integer,
    block_no integer,
    short text,
    long text,
    PRIMARY KEY (transliteration_id, block_no)
);

CREATE TABLE surfaces_display (
    transliteration_id integer,
    surface_no integer,
    short text,
    long text,
    PRIMARY KEY (transliteration_id, surface_no)
);

CREATE TABLE citations_display (
    text_id integer,
    extended_citation text
);


CREATE VIEW blocks_display_view AS
SELECT
    transliteration_id,
    block_no,
    @extschema:cuneiform_citation@.block_name_short(block_type, block_data) AS short,
    @extschema:cuneiform_citation@.block_name_long(block_type, block_data, block_comment) AS long
FROM
    @extschema:cuneiform_corpus@.blocks;


CREATE VIEW surfaces_display_view AS
SELECT
    transliteration_id,
    surface_no,
    @extschema:cuneiform_citation@.surface_name_short(surface_type, surface_data) AS short,
    @extschema:cuneiform_citation@.surface_name_long(surface_type, surface_data, surface_comment) AS long
FROM
    @extschema:cuneiform_corpus@.surfaces;

CREATE OR REPLACE VIEW citations_display_view AS
SELECT
    text_id,
    citation || 
        CASE WHEN count(*) OVER (PARTITION BY ensemble_id) > 1
            THEN COALESCE('('||type||')', '')
            ELSE ''
        END AS extended_citation
FROM
    @extschema:cuneiform_corpus@.texts
    LEFT JOIN @extschema:cuneiform_context@.objects USING (object_id);


CREATE FUNCTION blocks_display_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM @extschema@.blocks_display WHERE transliteration_id = (OLD).transliteration_id AND block_no = (OLD).block_no;
    ELSIF OLD IS NULL THEN
        INSERT INTO @extschema@.blocks_display SELECT * FROM @extschema@.blocks_display_view WHERE transliteration_id = (NEW).transliteration_id AND block_no = (NEW).block_no;
    ELSE
        UPDATE @extschema@.blocks_display SET 
            transliteration_id = (NEW).transliteration_id, 
            block_no = (NEW).block_no, 
            short = x.short, 
            long = x.long 
        FROM @extschema@.blocks_display_view x
        WHERE 
            blocks_display.transliteration_id = (OLD).transliteration_id
            AND blocks_display.block_no = (OLD).block_no
            AND x.transliteration_id = (NEW).transliteration_id
            AND x.block_no = (NEW).block_no;
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION surfaces_display_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM @extschema@.surfaces_display WHERE transliteration_id = (OLD).transliteration_id AND surface_no = (OLD).surface_no;
    ELSIF OLD IS NULL THEN
        INSERT INTO @extschema@.surfaces_display SELECT * FROM @extschema@.surfaces_display_view WHERE transliteration_id = (NEW).transliteration_id AND surface_no = (NEW).surface_no;
    ELSE
        UPDATE @extschema@.surfaces_display SET 
            transliteration_id = (NEW).transliteration_id, 
            surface_no = (NEW).surface_no, 
            short = x.short, 
            long = x.long 
        FROM @extschema@.surfaces_display_view x
        WHERE 
            surfaces_display.transliteration_id = (OLD).transliteration_id
            AND surfaces_display.surface_no = (OLD).surface_no
            AND x.transliteration_id = (NEW).transliteration_id
            AND x.surface_no = (NEW).surface_no;
    END IF;
    RETURN NULL;
END;
$BODY$;


CREATE FUNCTION citations_display_texts_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    DELETE FROM @extschema@.citations_display USING @extschema:cuneiform_corpus@.texts WHERE citations_display.text_id = texts.text_id AND citation IN ((OLD).citation, (NEW).citation);
    
    INSERT INTO @extschema@.citations_display
    SELECT 
        text_id, 
        extended_citation 
    FROM 
        @extschema@.citations_display_view 
        JOIN @extschema:cuneiform_corpus@.texts USING (text_id) 
    WHERE 
        citation IN ((OLD).citation, (NEW).citation);

    RETURN NULL;
END;
$BODY$;


CREATE FUNCTION citations_display_texts_simple_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    UPDATE @extschema@.citations_display 
    SET 
        extended_citation = citations_display_view.extended_citation 
    FROM
        @extschema@.citations_display_view
    WHERE 
        citations_display.text_id = (NEW).text_id 
        AND citations_display_view.text_id = (NEW).text_id ;

    RETURN NULL;
END;
$BODY$;


CREATE FUNCTION citations_display_objects_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    UPDATE @extschema@.citations_display
    SET 
        extended_citation = citations_display_view.extended_citation 
    FROM
        @extschema@.citations_display_view
        JOIN @extschema:cuneiform_corpus@.texts USING (text_id)
    WHERE 
        citations_display.text_id = texts.text_id 
        AND texts.object_id = (NEW).object_id;

    RETURN NULL;
END;
$BODY$;


CREATE TRIGGER blocks_display_trigger
  AFTER INSERT OR DELETE OR UPDATE ON @extschema:cuneiform_corpus@.blocks 
  FOR EACH ROW
  EXECUTE FUNCTION blocks_display_trigger_fun();

CREATE TRIGGER surfaces_display_trigger
  AFTER INSERT OR DELETE OR UPDATE ON @extschema:cuneiform_corpus@.surfaces 
  FOR EACH ROW
  EXECUTE FUNCTION surfaces_display_trigger_fun();

CREATE TRIGGER citations_display_texts_trigger
  AFTER INSERT OR DELETE OR UPDATE OF citation ON @extschema:cuneiform_corpus@.texts 
  FOR EACH ROW
  EXECUTE FUNCTION citations_display_texts_trigger_fun();

CREATE TRIGGER citations_display_texts_simple_trigger
  AFTER UPDATE OF object_id ON @extschema:cuneiform_corpus@.texts 
  FOR EACH ROW
  EXECUTE FUNCTION citations_display_texts_simple_trigger_fun();

CREATE TRIGGER citations_display_objects_trigger
  AFTER UPDATE ON @extschema:cuneiform_context@.objects 
  FOR EACH ROW
  EXECUTE FUNCTION citations_display_objects_trigger_fun();

INSERT INTO blocks_display SELECT * FROM blocks_display_view;
INSERT INTO surfaces_display SELECT * FROM surfaces_display_view;
INSERT INTO citations_display SELECT * FROM citations_display_view;