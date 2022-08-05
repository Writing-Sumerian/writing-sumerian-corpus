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

CREATE MATERIALIZED VIEW blocks_display AS
SELECT
    transliteration_id,
    block_no,
    coalesce (
        CASE block_type
        WHEN 'column' THEN
            romanize_column (block_data)
        WHEN 'summary' THEN
            romanize_column (block_data)
        WHEN 'block' THEN
            block_data
        ELSE
            block_type || ' ' || block_data
        END, '') AS short,
    coalesce (
        CASE block_type
        WHEN 'column' THEN
            romanize_column (block_data)
        WHEN 'summary' THEN
            romanize_column (block_data)
        WHEN 'block' THEN
            block_data
        ELSE
            block_type || ' ' || block_data
        END, '') || coalesce(block_comment, '') AS long
FROM
    blocks;

CREATE UNIQUE INDEX ON blocks_display (transliteration_id, block_no);

CREATE MATERIALIZED VIEW surfaces_display AS
SELECT
    transliteration_id,
    surface_no,
    coalesce (
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
        ELSE
            surface_data
        END, '') AS short,
    coalesce (
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
        ELSE
            surface_data
        END, '') || coalesce(surface_comment, '') AS long
FROM
    surfaces;

CREATE UNIQUE INDEX ON surfaces_display (transliteration_id, surface_no);

CREATE MATERIALIZED VIEW objects_display AS
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

CREATE UNIQUE INDEX ON objects_display (transliteration_id, object_no);