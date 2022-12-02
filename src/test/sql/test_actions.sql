
CREATE OR REPLACE FUNCTION test_actions_merge ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
v_queries text[];
v_query text;
BEGIN
CALL parse(E'1\ta--a a-a--a', 'public', 'sumerian', false, -1);
SELECT array_agg(query ORDER BY ordinality DESC) INTO v_queries FROM merge_entries(-1, 0, 'compounds', 'compound_no', 'words', 'word_no', 'public') WITH ORDINALITY;
RETURN NEXT is(content, E'1\ta--a--a-a--a') FROM corpus_code_transliterations WHERE transliteration_id = -1;
FOREACH v_query IN ARRAY v_queries LOOP
    DISCARD PLANS;
    RAISE INFO USING MESSAGE = v_query;
    EXECUTE v_query USING 'public';
END LOOP;
RETURN NEXT is(content, E'1\ta--a a-a--a') FROM corpus_code_transliterations WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_actions_split ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
v_queries text[];
v_query text;
BEGIN
CALL parse(E'1\ta--a a-a--a', 'public', 'sumerian', false, -1);
SELECT array_agg(query ORDER BY ordinality DESC) INTO v_queries FROM split_entry(-1, 0, 'words', 'word_no', 'compounds', 'compound_no', ROW(-1, 0, 'person', 'sumerian', null, null), 'public') WITH ORDINALITY;
RETURN NEXT is(content, E'1\t%person a a a-a--a') FROM corpus_code_transliterations WHERE transliteration_id = -1;
FOREACH v_query IN ARRAY v_queries LOOP
    DISCARD PLANS;
    RAISE INFO USING MESSAGE = v_query;
    EXECUTE v_query USING 'public';
END LOOP;
RETURN NEXT is(content, E'1\ta--a a-a--a') FROM corpus_code_transliterations WHERE transliteration_id = -1;
END;
$BODY$;