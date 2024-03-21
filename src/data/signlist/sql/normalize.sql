CREATE OR REPLACE FUNCTION split_sign (
    v_sign text
  )
  RETURNS TABLE(component text, op text)
  LANGUAGE SQL
  IMMUTABLE
  STRICT
  ROWS 2
BEGIN ATOMIC
  SELECT 
      regexp_split_to_table(v_sign, '([()+.&%×]|@[gštnkzi0-9]*)+'), 
      regexp_split_to_table(regexp_replace(v_sign, '^\(', 'V('), '[A-ZŠĜŘḪṬṢŚ’]+[x0-9]*([a-c]|bis|ter)?|(?<![@0-9])[0-9]+');
END;

CREATE OR REPLACE FUNCTION split_glyphs (
    v_sign text
  )
  RETURNS TABLE(glyph text)
  LANGUAGE PLPYTHON3U
  IMMUTABLE
  STRICT
  ROWS 2
AS $BODY$
    j = 0
    level = 0
    for i, c in enumerate(v_sign):
        if c == '(':
            level += 1
        elif c == ')':
            level -= 1
        elif not level and c == '.':
            yield v_sign[j:i]
            j = i+1
    yield v_sign[j:]
$BODY$;


CREATE OR REPLACE FUNCTION normalize_operators (
    v_sign text
  )
  RETURNS text
  STRICT
  IMMUTABLE
  LANGUAGE SQL
BEGIN ATOMIC
  SELECT compose_sign(normalize_sign(parse_sign(v_sign)));
END;


CREATE OR REPLACE FUNCTION normalize_glyphs (
    v_glyphs text
    )
    RETURNS text
    STRICT
    STABLE
    LANGUAGE SQL
    COST 10000
BEGIN ATOMIC
    SELECT 
        string_agg(glyphs, '.' ORDER BY sign_no) AS normalized_sign
    FROM (
        SELECT
            sign_no,
            normalize_operators(string_agg(op||COALESCE('('||glyphs||')', ''), '' ORDER BY component_no)) AS glyphs
        FROM
            LATERAL split_glyphs(v_glyphs) WITH ORDINALITY as a(sign, sign_no)
            LEFT JOIN LATERAL split_sign(sign) WITH ORDINALITY AS b(component, op, component_no) ON TRUE
            LEFT JOIN sign_map ON component = identifier
        GROUP BY 
            sign_no
        ) _;
END;