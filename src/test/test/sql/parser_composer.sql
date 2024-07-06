CREATE OR REPLACE FUNCTION compare_transliteration (transliteration_id_1 integer, transliteration_id_2 integer)
    RETURNS SETOF text
    STABLE
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
t text[];
columns text;
BEGIN
FOREACH t SLICE 1 IN ARRAY array[['corpus', 'sign_no'], ['words', 'word_no'], ['compounds', 'compound_no'], ['lines', 'line_no'], ['blocks', 'block_no'], ['surfaces', 'surface_no'], ['sections', 'section_no']] LOOP
    SELECT string_agg(column_name, ', ') INTO columns FROM information_schema.columns WHERE table_schema = '@extschema:cuneiform_corpus@' AND table_name = t[1] AND column_name != 'transliteration_id';
    RETURN NEXT results_eq(
        format('SELECT %s FROM @extschema:cuneiform_corpus@.%I WHERE transliteration_id = %s ORDER BY %I', columns, t[1], transliteration_id_1, t[2]),
        format('SELECT %s FROM @extschema:cuneiform_corpus@.%I WHERE transliteration_id = %s ORDER BY %I', columns, t[1], transliteration_id_2, t[2]),
        transliteration_id_1::text || ' ' || t[1]);
END LOOP;
RETURN;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE serialize_and_parse (v_transliteration_id integer, v_transliteration_id_new integer)
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
code text;
BEGIN
SELECT content INTO code FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = v_transliteration_id;
IF code IS NULL THEN
    RETURN;
END IF;
CALL @extschema:cuneiform_parser@.parse(code, v_transliteration_id_new, '@extschema:cuneiform_corpus@');
END;
$BODY$;

CREATE OR REPLACE FUNCTION manually_test_parse_serialize (v_transliteration_id integer)
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema@.serialize_and_parse(v_transliteration_id, -1);
RETURN QUERY SELECT @extschema@.compare_transliteration (v_transliteration_id, -1);
CALL @extschema:cuneiform_actions@.delete_transliteration(-1, '@extschema:cuneiform_corpus@');
RETURN;
END;
$BODY$;
