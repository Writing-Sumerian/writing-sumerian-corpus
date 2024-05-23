CREATE TABLE pns (
  pn_id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  pn_type @extschema:cuneiform_sign_properties@.pn_type NOT NULL,
  language @extschema:cuneiform_sign_properties@.language,
  normal_form text
);


CREATE TABLE pn_variants (
  pn_id integer REFERENCES pns (pn_id) ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
  pn_variant_no integer,
  sign_meanings @extschema:cuneiform_sign_properties@.sign_meaning[],
  PRIMARY KEY (pn_id, pn_variant_no)
);


SELECT pg_catalog.pg_extension_config_dump('@extschema@.pns', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('@extschema@.pns', 'pn_id'), '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.pn_variants', '');


CREATE TABLE pn_variants_unnest (
  pn_id integer,
  pn_variant_no integer,
  sign_no integer,
  LIKE @extschema:cuneiform_sign_properties@.sign_meaning,
  PRIMARY KEY (pn_id, pn_variant_no, sign_no),
  FOREIGN KEY (pn_id, pn_variant_no) REFERENCES pn_variants (pn_id, pn_variant_no) ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
  FOREIGN KEY (value_id) REFERENCES values (value_id) DEFERRABLE INITIALLY IMMEDIATE,
  FOREIGN KEY (sign_id) REFERENCES signs (sign_id) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE VIEW pn_variants_unnest_view AS
  SELECT
    pn_id,
    pn_variant_no,
    ordinality-1,
    word_no, 
    value_id, 
    sign_id, 
    indicator_type, 
    phonographic, 
    stem,
    capitalized
  FROM
    pn_variants
    JOIN UNNEST(sign_meanings) WITH ORDINALITY ON TRUE;


CREATE OR REPLACE FUNCTION pn_variants_unnest_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
  DELETE FROM @extschema@.pn_variants_unnest 
    USING 
      new_table 
    WHERE 
      pn_variants_unnest.pn_id = new_table.pn_id 
      AND pn_variants_unnest.pn_variant_no = new_table.pn_variant_no;
  INSERT INTO @extschema@.pn_variants_unnest 
    SELECT 
      pn_variants_unnest_view.* 
    FROM 
      @extschema@.pn_variants_unnest_view
      JOIN new_table USING (pn_id, pn_variant_no);
  RETURN NULL;
END;
$BODY$;

CREATE TRIGGER pn_variants_unnest_update_trigger 
  AFTER UPDATE ON pn_variants
  REFERENCING NEW TABLE AS new_table
  FOR EACH STATEMENT
  EXECUTE FUNCTION pn_variants_unnest_trigger_fun ();
CREATE TRIGGER pn_variants_unnest_insert_trigger 
  AFTER INSERT ON pn_variants
  REFERENCING NEW TABLE AS new_table
  FOR EACH STATEMENT
  EXECUTE FUNCTION pn_variants_unnest_trigger_fun ();


CREATE OR REPLACE PROCEDURE load_pns (v_path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format('COPY @extschema@.pns FROM %L CSV NULL ''\N''', v_path || 'pns.csv');
EXECUTE format('COPY @extschema@.pn_variants FROM %L CSV NULL ''\N''', v_path || 'pn_variants.csv');
PERFORM setval(pg_get_serial_sequence('@extschema@.pns', 'pn_id'), max(pn_id)) FROM @extschema@.pns;

END

$BODY$;