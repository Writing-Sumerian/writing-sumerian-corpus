CREATE OR REPLACE FUNCTION last_agg (anyelement, anyelement)
  RETURNS anyelement
  LANGUAGE sql IMMUTABLE CALLED ON NULL INPUT PARALLEL SAFE AS
'SELECT $2';

CREATE AGGREGATE last (anyelement) (
    SFUNC    = last_agg,
    STYPE    = anyelement,
    PARALLEL = safe
);


CREATE OR REPLACE FUNCTION bool_and_ex_last_agg (integer, boolean)
    RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
'SELECT $1 & (2*$2::integer) + ($1 >> 1)';

CREATE OR REPLACE FUNCTION bool_and_ex_last_final (integer)
    RETURNS boolean
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
'SELECT ($1 & 1)::boolean';

CREATE AGGREGATE bool_and_ex_last (boolean) (
    SFUNC    = bool_and_ex_last_agg,
    FINALFUNC= bool_and_ex_last_final,
    STYPE    = integer,
    PARALLEL = safe,
    INITCOND = 3
);


CREATE OR REPLACE FUNCTION condition_agg_sfunc (sign_condition, sign_condition)
    RETURNS sign_condition
    LANGUAGE sql STABLE STRICT PARALLEL SAFE AS
$$
SELECT
    CASE 
        WHEN $1 = $2 THEN $1
        WHEN $2 = 'deleted' OR $2 = 'inserted' THEN null
        ELSE 'damaged' 
    END;
$$;

CREATE AGGREGATE condition_agg (sign_condition) (
    SFUNC       = condition_agg_sfunc,
    COMBINEFUNC = condition_agg_sfunc,
    STYPE       = sign_condition,
    PARALLEL    = safe
);