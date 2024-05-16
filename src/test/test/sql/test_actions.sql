
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
CALL @extschema:cuneiform_parser@.parse(E'1\ta--a a-a--a', '@extschema:cuneiform_corpus@', -1);
SELECT array_agg(@extschema:cuneiform_log@.edit_log_undo_query(-1, '@extschema:cuneiform_corpus@', entry_no, key_col, target, action, val_old) ORDER BY ordinality DESC) INTO v_queries FROM @extschema:cuneiform_actions@.merge_entries(-1, 0, 'compounds', 'compound_no', 'words', 'word_no', '@extschema:cuneiform_corpus@') WITH ORDINALITY;
RETURN NEXT is(content, E'1\ta--a--a-a--a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
FOREACH v_query IN ARRAY v_queries LOOP
    DISCARD PLANS;
    RAISE INFO USING MESSAGE = v_query;
    EXECUTE v_query;
END LOOP;
RETURN NEXT is(content, E'1\ta--a a-a--a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
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
CALL @extschema:cuneiform_parser@.parse(E'1\ta--a a-a--a', '@extschema:cuneiform_corpus@', -1);
SELECT array_agg(@extschema:cuneiform_log@.edit_log_undo_query(-1, '@extschema:cuneiform_corpus@', entry_no, key_col, target, action, val_old) ORDER BY ordinality DESC) INTO v_queries FROM @extschema:cuneiform_actions@.split_entry(-1, 0, 'words', 'word_no', 'compounds', 'compound_no', ROW(-1, 0, 'person', 'sumerian', null, null), '@extschema:cuneiform_corpus@') WITH ORDINALITY;
RETURN NEXT is(content, E'1\t%s %person a %u a a-a--a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
FOREACH v_query IN ARRAY v_queries LOOP
    DISCARD PLANS;
    RAISE INFO USING MESSAGE = v_query;
    EXECUTE v_query;
END LOOP;
RETURN NEXT is(content, E'1\ta--a a-a--a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;