CREATE TYPE cun_position;

CREATE FUNCTION cun_position_in (cstring)
    RETURNS cun_position
    AS 'cuneiform_search', 'position_in'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_out (cun_position)
    RETURNS cstring
    AS 'cuneiform_search', 'position_out'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_recv (internal)
    RETURNS cun_position
    AS 'cuneiform_search', 'position_recv'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_send (cun_position)
    RETURNS bytea
    AS 'cuneiform_search', 'position_send'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE TYPE cun_position (
   internallength = 4,
   passedbyvalue,
   input = cun_position_in,
   output = cun_position_out,
   receive = cun_position_recv,
   send = cun_position_send,
   alignment = integer
);


CREATE FUNCTION cun_position_less (cun_position, cun_position)
    RETURNS bool
    AS 'cuneiform_search', 'position_less'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_greater (cun_position, cun_position)
    RETURNS bool
    AS 'cuneiform_search', 'position_greater'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_leq (cun_position, cun_position)
    RETURNS bool
    AS 'cuneiform_search', 'position_leq'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_geq (cun_position, cun_position)
    RETURNS bool
    AS 'cuneiform_search', 'position_geq'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_equal (cun_position, cun_position)
    RETURNS bool
    AS 'cuneiform_search', 'position_equal'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_neq (cun_position, cun_position)
    RETURNS bool
    AS 'cuneiform_search', 'position_neq'
    LANGUAGE C
    IMMUTABLE STRICT;


CREATE OPERATOR < (
    leftarg = cun_position,
    rightarg = cun_position,
    procedure = cun_position_less,
    commutator = >,
    negator = >=,
    restrict = scalarltsel,
    join = scalarltjoinsel
);

CREATE OPERATOR > (
    leftarg = cun_position,
    rightarg = cun_position,
    procedure = cun_position_greater,
    commutator = <,
    negator = <=,
    restrict = scalargtsel,
    join = scalargtjoinsel
);

CREATE OPERATOR <= (
    leftarg = cun_position,
    rightarg = cun_position,
    procedure = cun_position_leq,
    commutator = >=,
    negator = >,
    restrict = scalarltsel,
    join = scalarltjoinsel
);

CREATE OPERATOR >= (
    leftarg = cun_position,
    rightarg = cun_position,
    procedure = cun_position_geq,
    commutator = <=,
    negator = <,
    restrict = scalargtsel,
    join = scalargtjoinsel
);

CREATE OPERATOR = (
    leftarg = cun_position,
    rightarg = cun_position,
    procedure = cun_position_equal,
    commutator = =,
    negator = <>,
    restrict = eqsel,
    join = eqjoinsel,
    HASHES,
    MERGES
);

CREATE OPERATOR <> (
    leftarg = cun_position,
    rightarg = cun_position,
    procedure = cun_position_neq,
    commutator = <>,
    negator = =,
    restrict = neqsel,
    join = neqjoinsel
);


CREATE FUNCTION cun_position_order (cun_position, cun_position)
    RETURNS integer
    AS 'cuneiform_search', 'position_order'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_equalimage (oid)
    RETURNS bool
    AS 'cuneiform_search', 'position_equalimage'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_hash (cun_position)
    RETURNS integer
    AS 'cuneiform_search', 'position_hash'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position_hash_extended (cun_position, bigint)
    RETURNS bigint
    AS 'cuneiform_search', 'position_hash_extended'
    LANGUAGE C
    IMMUTABLE STRICT;


CREATE OPERATOR FAMILY btree_cun_position_ops USING btree;

CREATE OPERATOR CLASS btree_cun_position_ops
    DEFAULT FOR TYPE cun_position USING btree FAMILY btree_cun_position_ops AS
        OPERATOR        1       <,
        OPERATOR        2       <=,
        OPERATOR        3       =,
        OPERATOR        4       >=,
        OPERATOR        5       >,
        FUNCTION        1       cun_position_order,
        FUNCTION        4       cun_position_equalimage;

CREATE OPERATOR FAMILY hash_cun_position_ops USING hash;

CREATE OPERATOR CLASS hash_cun_position_ops
    DEFAULT FOR TYPE cun_position USING hash FAMILY hash_cun_position_ops AS
        OPERATOR        1       =,
        FUNCTION        1       cun_position_hash,
        FUNCTION        2       cun_position_hash_extended;

CREATE OPERATOR FAMILY brin_cun_position_minmax_ops USING brin;

CREATE OPERATOR CLASS brin_cun_position_minmax_ops
    DEFAULT FOR TYPE cun_position USING brin FAMILY brin_cun_position_minmax_ops AS
        OPERATOR        1       <,
        OPERATOR        2       <=,
        OPERATOR        3       =,
        OPERATOR        4       >=,
        OPERATOR        5       >,
        FUNCTION        1       brin_minmax_opcinfo,
        FUNCTION        2       brin_minmax_add_value,
        FUNCTION        3       brin_minmax_consistent,
        FUNCTION        4       brin_minmax_union;

CREATE FUNCTION next (cun_position)
    RETURNS cun_position
    AS 'cuneiform_search', 'position_next'
    LANGUAGE C
    IMMUTABLE STRICT;


CREATE FUNCTION sign_no(cun_position)
    RETURNS int
    AS 'cuneiform_search', 'position_sign_no'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION component_no(cun_position)
    RETURNS int
    AS 'cuneiform_search', 'position_component_no'
    LANGUAGE C
    IMMUTABLE STRICT;

CREATE FUNCTION cun_position(bigint, integer, bool)
    RETURNS cun_position
    AS 'cuneiform_search', 'position_construct'
    LANGUAGE C
    IMMUTABLE STRICT;




CREATE OR REPLACE FUNCTION uniq (VARIADIC cun_position[])
    RETURNS bool
    AS 'cuneiform_search', 'unique'
    LANGUAGE C
    IMMUTABLE
    COST 10;

CREATE OR REPLACE FUNCTION consecutive (VARIADIC cun_position[])
    RETURNS bool
    AS 'cuneiform_search', 'consecutive'
    LANGUAGE C
    IMMUTABLE
    COST 10;

CREATE OR REPLACE FUNCTION get_sign_nos (VARIADIC cun_position[])
    RETURNS int[]
    AS 'cuneiform_search', 'get_sign_nos'
    LANGUAGE C
    IMMUTABLE
    COST 10;

CREATE OR REPLACE FUNCTION sort_uniq_remove_null (VARIADIC integer[])
    RETURNS int[]
    AS 'cuneiform_search', 'sort_uniq_remove_null'
    LANGUAGE C
    IMMUTABLE
    COST 10;


CREATE TYPE search_wildcard AS (
    wildcard_id integer,
    sign_nos integer[]
);


CREATE VIEW values_search (value, sign_spec, code) AS
SELECT
    value,
    null,
    'v' || value_id::text
FROM
    value_variants
    LEFT JOIN values USING (value_id)
UNION ALL
SELECT
    value,
    glyphs,
    'v' || value_id::text || 's' || sign_variant_id::text
FROM
    value_variants
    LEFT JOIN values USING (value_id)
    JOIN sign_variants_composition USING (sign_id)
UNION ALL
SELECT
    value,
    CASE WHEN i = 1 THEN NULL ELSE glyphs END,
    'v' || value_id::text || 's' || sign_variant_id::text
FROM
    glyph_values 
    JOIN sign_variants_composition USING (glyph_ids)
    LEFT JOIN LATERAL generate_series(1, 2) AS _(i) ON TRUE;


CREATE VIEW signs_search (sign, sign_spec, code) AS
SELECT
    upper(value),
    CASE WHEN i = 1 THEN NULL ELSE glyphs END,
    's' || sign_variant_id::text
FROM
    value_variants
    LEFT JOIN values USING (value_id)
    JOIN sign_variants_composition USING (sign_id)
    LEFT JOIN LATERAL generate_series(1, 2) AS _(i) ON TRUE
    UNION ALL
SELECT
    upper(value),
    CASE WHEN i = 1 THEN NULL ELSE glyphs END,
    's' || sign_variant_id::text
FROM
    glyph_values 
    JOIN sign_variants_composition USING (glyph_ids)
    LEFT JOIN LATERAL generate_series(1, 2) AS _(i) ON TRUE;


CREATE VIEW sign_descriptions_search (sign, sign_spec, code) AS
SELECT
    a.glyphs,
    CASE WHEN i = 1 THEN NULL ELSE b.glyphs END,
    's' || b.sign_variant_id::text
FROM
    sign_variants_composition a
    JOIN sign_variants_composition b USING (sign_id)
    LEFT JOIN LATERAL generate_series(1, 2) AS _(i) ON TRUE
WHERE
    a.specific;


CREATE OR REPLACE VIEW forms_search (form, sign_spec, code) AS
WITH graphemes AS (
    SELECT
        sign_id,
        allomorph_id,
        pos,
        '(g' || grapheme_id::text || '|' || string_agg('c' || glyph_id::text, '|') || ')' AS code
    FROM
        allomorphs
        LEFT JOIN allomorph_components USING (allomorph_id)
        LEFT JOIN allographs USING (grapheme_id)
    WHERE 
        allomorphs.specific AND allographs.specific
    GROUP BY 
        sign_id,
        allomorph_id,
        grapheme_id,
        pos
)
SELECT
    upper(value),
    NULL,
    string_agg(code, '~' ORDER BY pos)
FROM
    value_variants
    LEFT JOIN values USING (value_id)
    LEFT JOIN graphemes USING (sign_id)
GROUP BY
    value,
    allomorph_id
UNION ALL
SELECT
    upper(value),
    glyphs,
    string_agg('c' || glyph_id::text, '~' ORDER BY pos)
FROM
    value_variants
    LEFT JOIN values USING (value_id)
    LEFT JOIN sign_variants_composition USING (sign_id)
    LEFT JOIN LATERAL unnest(glyph_ids) WITH ORDINALITY AS _(glyph_id, pos) ON TRUE
GROUP BY
    value,
    sign_variant_id,
    glyphs
UNION ALL
SELECT
    upper(value),
    CASE WHEN i = 1 THEN NULL ELSE string_agg(glyph, '.' ORDER BY pos) END,
    string_agg('c' || glyph_id::text, '~')
FROM
    glyph_values
    LEFT JOIN LATERAL unnest(glyph_ids) WITH ORDINALITY AS _(glyph_id, pos) ON TRUE
    LEFT JOIN glyphs USING (glyph_id)
    LEFT JOIN LATERAL generate_series(1, 2) AS __(i) ON TRUE
GROUP BY
    value,
    i;

CREATE OR REPLACE VIEW form_descriptions_search (form, sign_spec, code) AS
SELECT
    grapheme,
    NULL,
    'g' || grapheme_id::text
FROM
    graphemes
UNION ALL
SELECT
    grapheme,
    glyph,
    'c' || glyph_id::text
FROM
    graphemes
    LEFT JOIN allographs USING (grapheme_id)
    LEFT JOIN glyphs USING (glyph_id)
UNION ALL
SELECT
    glyph,
    NULL,
    'c' || glyph_id::text
FROM
    glyphs;
