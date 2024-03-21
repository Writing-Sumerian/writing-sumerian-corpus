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


CREATE OR REPLACE FUNCTION romanize_column (v_col text)
  RETURNS text STRICT IMMUTABLE
  LANGUAGE 'plpython3u'
AS $BODY$
  import roman
  import re
  return re.sub('[0-9]+', lambda m: str(roman.toRoman(int(m.group(0)))).lower(), v_col)
$BODY$;


CREATE FUNCTION block_name_short (
    v_block_type @extschema:cuneiform_create_corpus@.block_type,
    v_block_data text
  )
  RETURNS text
  LANGUAGE SQL
  IMMUTABLE
BEGIN ATOMIC
  SELECT CASE v_block_type
    WHEN 'column' THEN
      romanize_column (v_block_data)
    WHEN 'summary' THEN
      romanize_column (v_block_data)
    WHEN 'block' THEN
      COALESCE(v_block_data, '')
    ELSE
      v_block_type || COALESCE(' ' || v_block_data, '')
    END;
END;


CREATE FUNCTION block_name_long (
    v_block_type @extschema:cuneiform_create_corpus@.block_type,
    v_block_data text,
    v_block_comment text
  )
  RETURNS text
  LANGUAGE SQL
  IMMUTABLE
BEGIN ATOMIC
  SELECT 
    CASE v_block_type
      WHEN 'column' THEN
        romanize_column (v_block_data)
      WHEN 'summary' THEN
        romanize_column (v_block_data)
      WHEN 'block' THEN
        COALESCE(v_block_data, '')
      ELSE
        v_block_type || COALESCE(' ' || v_block_data, '')
    END || COALESCE(v_block_comment, '');
END;


CREATE FUNCTION surface_name_short (
    v_surface_type @extschema:cuneiform_create_corpus@.surface_type,
    v_surface_data text
  )
  RETURNS text
  LANGUAGE SQL
  IMMUTABLE
BEGIN ATOMIC
  SELECT 
    CASE v_surface_type
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
        COALESCE(v_surface_data, '')
      ELSE
        v_surface_type || COALESCE(' ' || v_surface_data, '')
    END;
END;


CREATE FUNCTION surface_name_long (
    v_surface_type @extschema:cuneiform_create_corpus@.surface_type,
    v_surface_data text,
    v_surface_comment text
  )
  RETURNS text
  LANGUAGE SQL
  IMMUTABLE
BEGIN ATOMIC
  SELECT 
    CASE v_surface_type
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
        COALESCE(v_surface_data, '')
      ELSE
        v_surface_type || COALESCE(' ' || v_surface_data, '')
    END || COALESCE(v_surface_comment, '');
END;