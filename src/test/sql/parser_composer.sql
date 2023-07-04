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
FOREACH t SLICE 1 IN ARRAY array[['corpus', 'sign_no'], ['words', 'word_no'], ['compounds', 'compound_no'], ['lines', 'line_no'], ['blocks', 'block_no'], ['surfaces', 'surface_no'], ['objects', 'object_no']] LOOP
    SELECT string_agg(column_name, ', ') INTO columns FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t[1] AND column_name != 'transliteration_id';
    RETURN NEXT results_eq(
        format('SELECT %s FROM %I WHERE transliteration_id = %s ORDER BY %I', columns, t[1], transliteration_id_1, t[2]),
        format('SELECT %s FROM %I WHERE transliteration_id = %s ORDER BY %I', columns, t[1], transliteration_id_2, t[2]),
        transliteration_id_1::text || ' ' || t[1]);
END LOOP;
RETURN;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE test.compose_and_parse (v_transliteration_id integer, v_transliteration_id_new integer)
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
code text;
stemmed boolean;
BEGIN
SELECT content INTO code FROM corpus_code_transliterations WHERE transliteration_id = v_transliteration_id;
IF code IS NULL THEN
    RETURN;
END IF;
SELECT name_short = 'Glossar' OR name_short = 'Attinger' INTO stemmed FROM transliterations JOIN corpora USING (corpus_id) WHERE transliteration_id = v_transliteration_id;
CALL parse(code, 'public', 'sumerian', stemmed, v_transliteration_id_new);
END;
$BODY$;

CREATE OR REPLACE FUNCTION manually_test_parser_composer (v_transliteration_id integer)
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
code text;
stemmed boolean;
BEGIN
CALL @extschema@.compose_and_parse(v_transliteration_id, -1);
RETURN QUERY SELECT @extschema@.compare_transliteration (v_transliteration_id, -1);
CALL delete_transliteration(-1, 'public');
RETURN;
END;
$BODY$;
