CREATE OR REPLACE FUNCTION last_agg (anyelement, anyelement)
  RETURNS anyelement
  IMMUTABLE
  CALLED ON NULL INPUT
  PARALLEL SAFE
  LANGUAGE SQL   
AS $BODY$
    SELECT $2;
$BODY$;


CREATE AGGREGATE last (anyelement) (
    SFUNC    = last_agg,
    STYPE    = anyelement,
    PARALLEL = safe
);


CREATE OR REPLACE FUNCTION bool_and_ex_last_agg (integer, boolean)
    RETURNS integer
    IMMUTABLE 
    STRICT 
    PARALLEL SAFE
    LANGUAGE SQL 
BEGIN ATOMIC
    SELECT $1 & (2*$2::integer) + ($1 >> 1);
END;


CREATE OR REPLACE FUNCTION bool_and_ex_last_final (integer)
    RETURNS boolean
    IMMUTABLE 
    STRICT 
    PARALLEL SAFE
    LANGUAGE SQL 
BEGIN ATOMIC
    SELECT ($1 & 1)::boolean;
END;


CREATE AGGREGATE bool_and_ex_last (boolean) (
    SFUNC    = bool_and_ex_last_agg,
    FINALFUNC= bool_and_ex_last_final,
    STYPE    = integer,
    PARALLEL = safe,
    INITCOND = 3
);