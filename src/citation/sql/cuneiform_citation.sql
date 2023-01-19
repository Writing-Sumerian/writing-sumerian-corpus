CREATE OR REPLACE FUNCTION citation_agg_sfunc (
    internal, 
    text, 
    integer, 
    text, 
    integer, 
    text, 
    integer
    )
    RETURNS internal
    AS 'cuneiform_citation'
,
    'cuneiform_citation_agg_sfunc'
    LANGUAGE C
    IMMUTABLE
    COST 10;

CREATE OR REPLACE FUNCTION citation_agg_finalfunc (internal)
    RETURNS text
    AS 'cuneiform_citation'
,
    'cuneiform_citation_agg_finalfunc'
    LANGUAGE C
    STRICT 
    IMMUTABLE
    COST 10;

CREATE AGGREGATE citation_agg (
    text, 
    integer, 
    text, 
    integer, 
    text, 
    integer
    ) (
    SFUNC = citation_agg_sfunc,
    STYPE = internal,
    FINALFUNC = citation_agg_finalfunc
);


CREATE OR REPLACE FUNCTION romanize_column (col text)
    RETURNS text STRICT IMMUTABLE
    LANGUAGE 'plpython3u'
    AS $BODY$
    import roman
    import re
    return re.sub('[0-9]+', lambda m: str(roman.toRoman(int(m.group(0)))).lower(), col)
$BODY$;


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

CREATE TABLE objects_display (
    transliteration_id integer,
    object_no integer,
    name text,
    sort_order integer,
    PRIMARY KEY (transliteration_id, object_no)
);


CREATE VIEW blocks_display_view AS
SELECT
    transliteration_id,
    block_no,
    CASE block_type
        WHEN 'column' THEN
            romanize_column (block_data)
        WHEN 'summary' THEN
            romanize_column (block_data)
        WHEN 'block' THEN
            COALESCE(block_data, '')
        ELSE
            block_type || COALESCE(' ' || block_data, '')
    END AS short,
    CASE block_type
        WHEN 'column' THEN
            romanize_column (block_data)
        WHEN 'summary' THEN
            romanize_column (block_data)
        WHEN 'block' THEN
            COALESCE(block_data, '')
        ELSE
            block_type || COALESCE(' ' || block_data, '')
    END || COALESCE(block_comment, '') AS long
FROM
    blocks;


CREATE VIEW surfaces_display_view AS
SELECT
    transliteration_id,
    surface_no,
    CASE surface_type
        WHEN 'obverse' THEN
            'o.'
        WHEN 'reverse' THEN
            'r.'
        WHEN 'top' THEN
            'u.e.'
        WHEN 'bottom' THEN
            'lo.e.'
        WHEN 'left' THEN
            'l.e.'
        WHEN 'right' THEN
            'r.e.'
        WHEN 'surface' THEN
            COALESCE(surface_data, '')
        ELSE
            surface_type || COALESCE(' ' || surface_data, '')
    END AS short,
    CASE surface_type
        WHEN 'obverse' THEN
            'obverse'
        WHEN 'reverse' THEN
            'reverse'
        WHEN 'top' THEN
            'upper edge'
        WHEN 'bottom' THEN
            'lower edge'
        WHEN 'left' THEN
            'left edge'
        WHEN 'right' THEN
            'right edge'
        WHEN 'surface' THEN
            COALESCE(surface_data, '')
        ELSE
            surface_type || COALESCE(' ' || surface_data, '')
    END || COALESCE(surface_comment, '') AS long
FROM
    surfaces;


CREATE VIEW objects_display_view AS
SELECT
    transliteration_id,
    object_no,
    coalesce (
        CASE object_type
        WHEN 'object' THEN
            object_data
        ELSE
            object_type::text
        END, '') || coalesce(object_comment, '') AS name,
        CASE object_type
    WHEN 'envelope' THEN
        0
    WHEN 'tablet' THEN
        1
    WHEN 'object' THEN
        2
    WHEN 'seal' THEN
        3
    END AS sort_order
FROM
    objects;


CREATE FUNCTION blocks_display_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM blocks_display WHERE transliteration_id = (OLD).transliteration_id AND block_no = (OLD).block_no;
    ELSIF OLD IS NULL THEN
        INSERT INTO blocks_display SELECT * FROM blocks_display_view WHERE transliteration_id = (NEW).transliteration_id AND block_no = (NEW).block_no;
    ELSE
        UPDATE blocks_display SET 
            transliteration_id = (NEW).transliteration_id, 
            block_no = (NEW).block_no, 
            short = x.short, 
            long = x.long 
        FROM blocks_display_view x
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
        DELETE FROM surfaces_display WHERE transliteration_id = (OLD).transliteration_id AND surface_no = (OLD).surface_no;
    ELSIF OLD IS NULL THEN
        INSERT INTO surfaces_display SELECT * FROM surfaces_display_view WHERE transliteration_id = (NEW).transliteration_id AND surface_no = (NEW).surface_no;
    ELSE
        UPDATE surfaces_display SET 
            transliteration_id = (NEW).transliteration_id, 
            surface_no = (NEW).surface_no, 
            short = x.short, 
            long = x.long 
        FROM surfaces_display_view x
        WHERE 
            surfaces_display.transliteration_id = (OLD).transliteration_id
            AND surfaces_display.surface_no = (OLD).surface_no
            AND x.transliteration_id = (NEW).transliteration_id
            AND x.surface_no = (NEW).surface_no;
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION objects_display_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM objects_display WHERE transliteration_id = (OLD).transliteration_id AND object_no = (OLD).object_no;
    ELSIF OLD IS NULL THEN
        INSERT INTO objects_display SELECT * FROM objects_display_view WHERE transliteration_id = (NEW).transliteration_id AND object_no = (NEW).object_no;
    ELSE
        UPDATE objects_display SET 
            transliteration_id = (NEW).transliteration_id, 
            object_no = (NEW).object_no, 
            name = x.name, 
            sort_order = x.sort_order 
        FROM objects_display_view x
        WHERE 
            objects_display.transliteration_id = (OLD).transliteration_id
            AND objects_display.object_no = (OLD).object_no
            AND x.transliteration_id = (NEW).transliteration_id
            AND x.object_no = (NEW).object_no;
    END IF;
    RETURN NULL;
END;
$BODY$;


CREATE TRIGGER blocks_display_trigger
  AFTER INSERT OR DELETE OR UPDATE ON blocks 
  FOR EACH ROW
  EXECUTE FUNCTION blocks_display_trigger_fun();

CREATE TRIGGER surfaces_display_trigger
  AFTER INSERT OR DELETE OR UPDATE ON surfaces 
  FOR EACH ROW
  EXECUTE FUNCTION surfaces_display_trigger_fun();

CREATE TRIGGER objects_display_trigger
  AFTER INSERT OR DELETE OR UPDATE ON objects 
  FOR EACH ROW
  EXECUTE FUNCTION objects_display_trigger_fun();

INSERT INTO blocks_display SELECT * FROM blocks_display_view;
INSERT INTO surfaces_display SELECT * FROM surfaces_display_view;
INSERT INTO objects_display SELECT * FROM objects_display_view;