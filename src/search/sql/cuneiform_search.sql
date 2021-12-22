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

