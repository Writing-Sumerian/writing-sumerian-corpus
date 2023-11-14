CREATE OR REPLACE PROCEDURE edit_corpus (
    v_source_schema text, 
    v_transliteration_id integer,
    v_user_id integer DEFAULT NULL,
    v_internal boolean DEFAULT false
    )
    LANGUAGE PLPGSQL
AS $BODY$
DECLARE
    v_edit_id       integer;
BEGIN
    INSERT INTO edits (transliteration_id, timestamp, user_id, internal) 
    SELECT 
        v_transliteration_id, 
        CURRENT_TIMESTAMP, 
        v_user_id,
        v_internal
    RETURNING edit_id INTO v_edit_id;

    INSERT INTO edit_log 
    SELECT
        v_edit_id,
        ordinality,
        entry_no,
        key_col,
        target,
        action,
        val,
        val_old
    FROM
        edit(v_source_schema, 'public', v_transliteration_id) WITH ORDINALITY;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE edit_transliteration (
    v_code text, 
    v_transliteration_id integer,
    v_language language,
    v_stemmed boolean,
    v_user_id integer DEFAULT NULL,
    v_internal boolean DEFAULT false
    )
    LANGUAGE PLPGSQL
AS $BODY$

DECLARE

    v_error text;

BEGIN

    CALL parse(v_code, 'editor', v_language, v_stemmed, v_transliteration_id);

    SELECT string_agg(format('"%s" near %s:%s', message, line, col),  E'\n') INTO v_error FROM editor.errors;
    IF length(v_error) > 0 THEN
        RAISE EXCEPTION 'cuneiform_parser syntax error:%', v_error;
    END IF;

    SELECT 
        string_agg(format('"%s" in %s:%s-%s', value || COALESCE('('||sign_spec||')', ''), line_no_code, start_col_code, stop_col_code),  E'\n') 
    INTO 
        v_error 
    FROM 
        corpus_parsed_unencoded
    WHERE 
        transliteration_id = v_transliteration_id;

    IF length(v_error) > 0 THEN
        RAISE EXCEPTION 'cuneiform_parser encoding error:%', v_error;
    END IF;

    CALL edit_corpus('editor', v_transliteration_id, v_user_id, v_internal);
    CALL delete_transliteration(v_transliteration_id, 'editor');

END;

$BODY$;