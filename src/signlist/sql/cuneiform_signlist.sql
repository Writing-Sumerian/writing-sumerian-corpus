CREATE TABLE signs (
    sign_id serial PRIMARY KEY,
    sign text NOT NULL UNIQUE DEFERRABLE INITIALLY IMMEDIATE,
    composition text NOT NULL UNIQUE DEFERRABLE INITIALLY IMMEDIATE,
    unicode text,
    mzl_no text
);

CREATE TABLE unknown_signs (
    name text PRIMARY KEY,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE values (
    value_id serial PRIMARY KEY,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY IMMEDIATE,
    main_variant_id integer NOT NULL,
    phonographic boolean
);

CREATE TABLE value_variants (
    value_variant_id serial PRIMARY KEY,
    value_id integer NOT NULL REFERENCES values (value_id) DEFERRABLE INITIALLY IMMEDIATE,
    value text NOT NULL,
    UNIQUE (value_variant_id, value_id),  -- pointless, but required for foreign key on values
    UNIQUE (value_variant_id, value)
);

ALTER TABLE values ADD FOREIGN KEY (value_id, main_variant_id) REFERENCES value_variants (value_id, value_variant_id) DEFERRABLE INITIALLY DEFERRED;

SELECT pg_catalog.pg_extension_config_dump('signs', '');
SELECT pg_catalog.pg_extension_config_dump('unknown_signs', '');
SELECT pg_catalog.pg_extension_config_dump('values', '');
SELECT pg_catalog.pg_extension_config_dump('value_variants', '');

CREATE UNIQUE INDEX ON value_variants (value)
WHERE
    value NOT LIKE '%x';

CREATE INDEX value_index ON value_variants (value);


CREATE MATERIALIZED VIEW sign_composition AS (
SELECT 
    a.sign_id,
    b.sign_id AS component_sign_id,
    x.pos::integer - 1 AS pos,
    x.pos = 1 AS initial,
    x.pos = max(x.pos) OVER (PARTITION BY a.sign_id) AS final
FROM signs a,
    LATERAL unnest(string_to_array(a.composition, '.'::text)) WITH ORDINALITY x(part, pos)
    LEFT JOIN signs b ON x.part = b.composition);

CREATE MATERIALIZED VIEW sign_identifiers (sign_id, sign_identifier) AS
SELECT 
    sign_id,
    sign
FROM signs
UNION
SELECT
    sign_id,
    composition
FROM signs
UNION
SELECT
    sign_id,
    name
FROM unknown_signs
UNION
SELECT
    sign_id,
    upper(value)
FROM
    values
    JOIN value_variants USING (value_id);



CREATE VIEW signlist AS 
SELECT 
    sign_id, 
    unicode,
    sign,
    mzl_no,
    value_id, 
    value_variant_id, 
    value, 
    value_variant_id = main_variant_id AS main 
FROM value_variants 
JOIN values USING (value_id) 
JOIN signs USING (sign_id) 
ORDER BY 
    sign_id, 
    value_id, 
    main DESC,
    value;


CREATE OR REPLACE FUNCTION add_value (
  sign_ text, 
  value_ text,
  phonographic boolean DEFAULT null
  )
  RETURNS void
  LANGUAGE 'plpgsql'
  VOLATILE
  AS $BODY$
  DECLARE
    value_id_ integer;
  BEGIN
  WITH x AS (
      INSERT INTO values(sign_id, main_variant_id, phonographic) SELECT sign_id, -1, phonographic FROM signs WHERE sign = sign_ RETURNING value_id
  )
  INSERT INTO value_variants(value_id, value) SELECT value_id, value_ FROM x RETURNING value_id INTO value_id_;
  UPDATE values SET main_variant_id = value_variant_id FROM value_variants WHERE values.value_id = value_id_ AND value_variants.value_id = value_id_;
  END;
$BODY$;

CREATE OR REPLACE FUNCTION merge_values (
  value_id_1 integer, 
  value_id_2 integer
  )
  RETURNS void
  LANGUAGE 'plpgsql'
  VOLATILE
  AS $BODY$
  DECLARE
    same_sign bool;
  BEGIN
    SELECT a.sign_id = b.sign_id INTO same_sign FROM (SELECT sign_id FROM values WHERE value_id = value_id_1) a, (SELECT sign_id FROM values WHERE value_id = value_id_2) b; 
    ASSERT same_sign;
    UPDATE value_variants SET value_id = value_id_1 WHERE value_id = value_id_2;
    DELETE FROM values WHERE value_id = value_id_2;
END;
$BODY$;