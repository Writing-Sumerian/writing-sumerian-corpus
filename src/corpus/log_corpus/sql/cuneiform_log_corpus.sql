CREATE OR REPLACE VIEW corpus_modified AS
WITH corpus_edits AS (
    SELECT
        row_number() OVER (PARTITION BY transliteration_id ORDER BY edit_no DESC, log_no DESC) AS ord,
        transliteration_id,
        sign_no,
        edit_no,
        entry_no,
        split_part(action, ' ', 1) AS action,
        val
    FROM 
        @extschema:cuneiform_log_tables@.edit_log 
        JOIN @extschema:cuneiform_log_tables@.edits USING (transliteration_id, edit_no)
        JOIN @extschema:cuneiform_corpus@.corpus USING (transliteration_id)
    WHERE
        target = 'corpus'
    UNION ALL
    SELECT
        0,
        transliteration_id,
        sign_no,
        NULL,
        sign_no,
        NULL,
        NULL
    FROM @extschema:cuneiform_corpus@.corpus
)
SELECT
    transliteration_id,
    sign_no,
    log_agg(edit_no, action, entry_no, val ORDER BY ord) AS edit_nos
FROM
    corpus_edits
GROUP BY
    transliteration_id,
    sign_no;


CREATE OR REPLACE PROCEDURE undo (
    v_transliteration_id integer,
    v_edit_no integer, 
    v_schema text
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE

v_query text;

BEGIN
FOR v_query IN 
    SELECT 
        @extschema:cuneiform_log@.edit_log_undo_query(transliteration_id, v_schema, entry_no, key_col, target, action, val_old)
    FROM 
        @extschema:cuneiform_log_tables@.edit_log 
    WHERE 
        transliteration_id = v_transliteration_id
        AND edit_no = v_edit_no
    ORDER BY log_no DESC 
    LOOP
    RAISE INFO USING MESSAGE = v_query;
    DISCARD PLANS;
    EXECUTE v_query;
END LOOP;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE revert_to (
    v_transliteration_id integer, 
    v_timestamp timestamp with time zone, 
    v_schema text
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$

DECLARE

v_query text;

BEGIN
FOR v_query IN 
    SELECT 
        @extschema:cuneiform_log@.edit_log_undo_query(transliteration_id, v_schema, entry_no, key_col, target, action, val_old) 
    FROM 
        @extschema:cuneiform_log_tables@.edit_log 
        JOIN @extschema:cuneiform_log_tables@.edits USING (transliteration_id, edit_no)
    WHERE 
        transliteration_id = v_transliteration_id 
        AND timestamp > v_timestamp
    ORDER BY edit_no DESC, log_no DESC 
    LOOP
    RAISE INFO USING MESSAGE = v_query;
    DISCARD PLANS;
    EXECUTE v_query;
END LOOP;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE redo (
    v_transliteration_id integer,
    v_edit_no integer, 
    v_schema text
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE

v_query text;

BEGIN
FOR v_query IN 
    SELECT 
        @extschema:cuneiform_log@.edit_log_redo_query(transliteration_id, v_schema, entry_no, key_col, target, action, val) 
    FROM 
        @extschema:cuneiform_log_tables@.edit_log 
    WHERE 
        transliteration_id = v_transliteration_id
        AND edit_no = v_edit_no
    ORDER BY log_no
    LOOP
    RAISE INFO USING MESSAGE = v_query;
    DISCARD PLANS;
    EXECUTE v_query;
END LOOP;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE revert_corpus_to (
    v_transliteration_id integer, 
    v_timestamp timestamp with time zone
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
    CALL revert_to(v_transliteration_id, v_timestamp, '@extschema:cuneiform_corpus@');
    DELETE FROM @extschema:cuneiform_log_tables@.edits WHERE transliteration_id = v_transliteration_id AND timestamp > v_timestamp;
END;
$BODY$;