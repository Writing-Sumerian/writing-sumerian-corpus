CREATE OR REPLACE FUNCTION cun_agg_sfunc (
    internal, 
    text, 
    text,
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    sign_type,
    indicator_type,
    boolean,
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    pn_type,
    text,
    text,
    boolean
    )
    RETURNS internal
    AS 'cuneiform_serialize'
,
    'cuneiform_cun_agg_sfunc'
    LANGUAGE C
    IMMUTABLE
    COST 1000;

CREATE OR REPLACE FUNCTION cun_agg_finalfunc (internal)
    RETURNS text[]
    AS 'cuneiform_serialize'
,
    'cuneiform_cun_agg_finalfunc'
    LANGUAGE C
    STRICT 
    IMMUTABLE
    COST 1000;

CREATE AGGREGATE cun_agg (
    text, 
    text,
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    sign_type,
    indicator_type,
    boolean,
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    pn_type,
    text,
    text,
    boolean
    ) (
    SFUNC = cun_agg_sfunc,
    STYPE = internal,
    FINALFUNC = cun_agg_finalfunc
);


CREATE OR REPLACE FUNCTION identity(v_value text)
    RETURNS text
    IMMUTABLE
    LANGUAGE SQL
AS
$BODY$
    SELECT v_value;
$BODY$;


CREATE OR REPLACE FUNCTION print_spec_code (
        v_variant_type sign_variant_type,
        v_graphemes text, 
        v_glyphs text
    )
    RETURNS text
    IMMUTABLE
    LANGUAGE SQL
AS
$BODY$
    SELECT 
        CASE 
            WHEN v_variant_type = 'default' THEN '(' || v_graphemes || ')'
            WHEN v_variant_type = 'nondefault' THEN '(' || v_glyphs || ')' 
            ELSE '!(' || v_glyphs || ')' 
        END;
$BODY$;


CREATE OR REPLACE FUNCTION print_graphemes_code(v_graphemes text)
    RETURNS text
    IMMUTABLE
    LANGUAGE SQL
AS
$BODY$
    SELECT 
        CASE
            WHEN v_graphemes ~ '\.' THEN '|' || v_graphemes || '|'
            ELSE v_graphemes
        END;
$BODY$;


CALL create_signlist_print (
    'code', 
    'public', 
    'identity', 
    'print_spec_code', 
    'identity', 
    'identity',
    'print_graphemes_code'
);

CREATE OR REPLACE FUNCTION placeholder_code (type SIGN_TYPE)
    RETURNS text
    STRICT
    IMMUTABLE
    LANGUAGE SQL
AS $BODY$
    SELECT
        CASE type
        WHEN 'number' THEN
            'N'
        WHEN 'description' THEN
            'DESC'
        WHEN 'punctuation' THEN
            '|'
        WHEN 'damage' THEN
            '…'
        ELSE
            'X'
        END 
$BODY$;