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
    INSERT INTO @extschema:cuneiform_log_tables@.edits (transliteration_id, timestamp, user_id, internal) 
    SELECT 
        v_transliteration_id, 
        CURRENT_TIMESTAMP, 
        v_user_id,
        v_internal
    RETURNING edit_id INTO v_edit_id;

    INSERT INTO @extschema:cuneiform_log_tables@.edit_log 
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
        @extschema:cuneiform_editor@.edit(v_source_schema, '@extschema:cuneiform_corpus@', v_transliteration_id) WITH ORDINALITY;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE edit_transliteration (
    v_code text, 
    v_transliteration_id integer,
    v_language @extschema:cuneiform_sign_properties@.language,
    v_stemmed boolean,
    v_user_id integer DEFAULT NULL,
    v_internal boolean DEFAULT false
    )
    LANGUAGE PLPGSQL
AS $BODY$

DECLARE

    v_error text;

BEGIN

    CALL @extschema:cuneiform_create_corpus@.create_corpus('pg_temp', TRUE);
    CREATE TEMPORARY TABLE errors (
        transliteration_id integer,
        line integer,
        col integer,
        symbol text,
        message text
    ) ON COMMIT DROP;

    CALL @extschema:cuneiform_parser@.parse(v_code, 'pg_temp', v_language, v_stemmed, v_transliteration_id);

    SELECT string_agg(format('"%s" near %s:%s', message, line, col),  E'\n') INTO v_error FROM errors;
    IF length(v_error) > 0 THEN
        RAISE EXCEPTION 'cuneiform_parser syntax error:%', v_error;
    END IF;

    SELECT 
        string_agg(format('"%s" in %s:%s-%s', value || COALESCE('('||sign_spec||')', ''), line_no_code, start_col_code, stop_col_code),  E'\n') 
    INTO 
        v_error 
    FROM 
        @extschema:cuneiform_parser@.corpus_parsed_unencoded
    WHERE 
        transliteration_id = v_transliteration_id;

    IF length(v_error) > 0 THEN
        RAISE EXCEPTION 'cuneiform_parser encoding error:%', v_error;
    END IF;

    CALL @extschema@.edit_corpus('pg_temp', v_transliteration_id, v_user_id, v_internal);

END;

$BODY$;