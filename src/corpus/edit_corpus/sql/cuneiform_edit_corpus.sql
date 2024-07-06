CREATE OR REPLACE PROCEDURE edit_corpus (
    v_source_schema text, 
    v_transliteration_id integer,
    v_user_id integer DEFAULT NULL,
    v_internal boolean DEFAULT false
    )
    LANGUAGE PLPGSQL
AS $BODY$
DECLARE
    v_edit_no       integer;
    v_changes       boolean;
BEGIN
    SELECT COALESCE(max(edit_no)+1, 0) INTO v_edit_no FROM @extschema:cuneiform_log_tables@.edits WHERE transliteration_id = v_transliteration_id;

    INSERT INTO @extschema:cuneiform_log_tables@.edits
    SELECT 
        v_transliteration_id, 
        v_edit_no,
        CURRENT_TIMESTAMP, 
        v_user_id,
        v_internal;

    INSERT INTO @extschema:cuneiform_log_tables@.edit_log 
    SELECT
        v_transliteration_id,
        v_edit_no,
        ordinality,
        entry_no,
        key_col,
        target,
        action,
        val,
        val_old
    FROM
        @extschema:cuneiform_editor@.edit(v_source_schema, '@extschema:cuneiform_corpus@', v_transliteration_id) WITH ORDINALITY;

    SELECT count(*) > 0 INTO v_changes FROM @extschema:cuneiform_log_tables@.edit_log WHERE transliteration_id = v_transliteration_id AND edit_no = v_edit_no;
    IF NOT v_changes THEN
        DELETE FROM @extschema:cuneiform_log_tables@.edits WHERE transliteration_id = v_transliteration_id AND edit_no = v_edit_no;
    END IF;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE edit_transliteration (
    v_code text, 
    v_transliteration_id integer,
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
        LIKE @extschema:cuneiform_parser@.errors_type
    ) ON COMMIT DROP;
    CREATE TEMPORARY TABLE corpus_parsed_unencoded (
        LIKE @extschema:cuneiform_parser@.corpus_parsed_unencoded_type,
        PRIMARY KEY (transliteration_id, sign_no)
    ) ON COMMIT DROP;
    CALL @extschema:cuneiform_encoder@.create_corpus_encoder('corpus_encoder', 'corpus_parsed_unencoded', '{transliteration_id}', 'pg_temp');

    CALL @extschema:cuneiform_parser@.parse(v_code, v_transliteration_id, 'pg_temp', '@extschema:cuneiform_corpus@');

    SELECT string_agg(format('"%s" near %s:%s', message, line, col),  E'\n') INTO v_error FROM errors;
    IF length(v_error) > 0 THEN
        RAISE EXCEPTION 'cuneiform_parser syntax error:%', v_error;
    END IF;

    SELECT 
        string_agg(format('"%s" in %s:%s-%s', value || COALESCE('('||sign_spec||')', ''), line_no_code, start_col_code, stop_col_code),  E'\n') 
    INTO 
        v_error 
    FROM 
        pg_temp.corpus_parsed_unencoded
    WHERE 
        transliteration_id = v_transliteration_id;

    IF length(v_error) > 0 THEN
        RAISE EXCEPTION 'cuneiform_parser encoding error:%', v_error;
    END IF;

    CALL @extschema@.edit_corpus('pg_temp', v_transliteration_id, v_user_id, v_internal);
END;

$BODY$;