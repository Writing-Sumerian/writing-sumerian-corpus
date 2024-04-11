CREATE OR REPLACE FUNCTION cun_agg_sfunc (
    internal, 
    text, 
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    @extschema:cuneiform_sign_properties@.sign_type,
    @extschema:cuneiform_sign_properties@.indicator_type,
    boolean,
    boolean, 
    @extschema:cuneiform_sign_properties@.sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    @extschema:cuneiform_sign_properties@.pn_type,
    text,
    text
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
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    @extschema:cuneiform_sign_properties@.sign_type,
    @extschema:cuneiform_sign_properties@.indicator_type,
    boolean,
    boolean, 
    @extschema:cuneiform_sign_properties@.sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    @extschema:cuneiform_sign_properties@.pn_type,
    text,
    text
    ) (
    SFUNC = cun_agg_sfunc,
    STYPE = internal,
    FINALFUNC = cun_agg_finalfunc
);


CREATE OR REPLACE FUNCTION identity(v_value text)
    RETURNS text
    IMMUTABLE
    LANGUAGE SQL
BEGIN ATOMIC
    SELECT v_value;
END;


CREATE OR REPLACE FUNCTION print_spec_code (
        v_variant_type @extschema:cuneiform_signlist@.sign_variant_type,
        v_graphemes text, 
        v_glyphs text
    )
    RETURNS text
    IMMUTABLE
    LANGUAGE SQL
BEGIN ATOMIC
    SELECT 
        CASE 
            WHEN v_variant_type = 'default' THEN '(' || v_graphemes || ')'
            WHEN v_variant_type = 'nondefault' THEN '(' || v_glyphs || ')' 
            ELSE '!(' || v_glyphs || ')' 
        END;
END;


CREATE OR REPLACE FUNCTION print_graphemes_code(v_graphemes text)
    RETURNS text
    IMMUTABLE
    LANGUAGE SQL
BEGIN ATOMIC
    SELECT 
        CASE
            WHEN v_graphemes ~ '\.' THEN '|' || v_graphemes || '|'
            ELSE v_graphemes
        END;
END;


CALL @extschema:cuneiform_print_core@.create_signlist_print (
    'code', 
    '@extschema@', 
    'identity', 
    'print_spec_code', 
    'identity', 
    'identity',
    'print_graphemes_code'
);


CREATE OR REPLACE FUNCTION placeholder_code (v_type @extschema:cuneiform_sign_properties@.sign_type)
    RETURNS text
    STRICT
    IMMUTABLE
    LANGUAGE SQL
BEGIN ATOMIC
    SELECT
        CASE v_type
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
        END;
END;


CREATE OR REPLACE FUNCTION serialize_sign_meanings (v_sign_meanings @extschema:cuneiform_sign_properties@.sign_meaning[])
  RETURNS text
  STABLE
  COST 1000
  LANGUAGE SQL
BEGIN ATOMIC
    SELECT
        (cun_agg (character_print, ordinality::integer, word_no, 0, NULL, 0, (CASE WHEN unnest.value_id IS NULL THEN 'sign' ELSE 'value' END)::@extschema:cuneiform_sign_properties@.sign_type, indicator_type, phonographic, stem, 'intact'::@extschema:cuneiform_sign_properties@.sign_condition, language, 
            FALSE, FALSE, FALSE, NULL, NULL, false, NULL, NULL, NULL ORDER BY ordinality))[1]
    FROM
        unnest(v_sign_meanings) WITH ORDINALITY
        LEFT JOIN @extschema:cuneiform_signlist@.sign_variants USING (sign_id)
        LEFT JOIN characters_code ON characters_code.sign_variant_id = sign_variants.sign_variant_id AND unnest.value_id IS NOT DISTINCT FROM characters_code.value_id
    WHERE
        variant_type = 'default'
END;