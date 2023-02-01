CREATE OR REPLACE FUNCTION split_sign (
    sign text
    )
    RETURNS TABLE(component text, op text)
    LANGUAGE SQL
    IMMUTABLE
    STRICT
    ROWS 2
    AS $BODY$
    SELECT 
        regexp_split_to_table(sign, '([()+.&%×]|@[gštnkzi0-9]*)+'), 
        regexp_split_to_table(regexp_replace(sign, '^\(', 'V('), '[A-ZŠĜŘḪṬṢŚ’]+[x0-9]*([a-c]|bis|ter)?|(?<![@0-9])[0-9]+')
$BODY$;

CREATE OR REPLACE FUNCTION split_glyphs (
    sign text
    )
    RETURNS TABLE(glyph text)
    LANGUAGE PLPYTHON3U
    IMMUTABLE
    STRICT
    ROWS 2
    AS $BODY$
    j = 0
    level = 0
    for i, c in enumerate(sign):
        if c == '(':
            level += 1
        elif c == ')':
            level -= 1
        elif not level and c == '.':
            yield sign[j:i]
            j = i+1
    yield sign[j:]
$BODY$;


CREATE OR REPLACE FUNCTION normalize_operators (
    sign text
    )
    RETURNS text
    STRICT
    IMMUTABLE
    LANGUAGE SQL
    AS $BODY$
    SELECT compose_sign(normalize_sign(parse_sign(sign)));
$BODY$;

CREATE OR REPLACE FUNCTION normalize_glyphs (
    glyphs text
    )
    RETURNS text
    STRICT
    STABLE
    LANGUAGE SQL
    AS $BODY$
    SELECT 
        string_agg(glyphs, '.' ORDER BY sign_no) AS normalized_sign
    FROM (
        SELECT
            sign_no,
            normalize_operators(string_agg(op||COALESCE('('||glyphs||')', ''), '' ORDER BY component_no)) AS glyphs
        FROM
            LATERAL split_glyphs(glyphs) WITH ORDINALITY as a(sign, sign_no)
            LEFT JOIN LATERAL split_sign(sign) WITH ORDINALITY AS b(component, op, component_no) ON TRUE
            LEFT JOIN sign_map ON component = identifier
        GROUP BY 
            sign_no
        ) _
$BODY$;