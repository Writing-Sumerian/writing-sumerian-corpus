CREATE OR REPLACE VIEW corpus_modified AS
WITH corpus_edits AS (
    SELECT
        row_number() OVER (PARTITION BY transliteration_id ORDER BY edit_id DESC, log_no DESC) AS ord,
        transliteration_id,
        sign_no,
        edit_id::integer,
        entry_no,
        split_part(action, ' ', 1) AS action,
        val
    FROM 
        edit_log 
        JOIN edits USING (edit_id)
        JOIN corpus USING (transliteration_id)
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
    FROM corpus
)
SELECT
    transliteration_id,
    sign_no,
    log_agg(edit_id, action, entry_no, val ORDER BY ord) AS edit_ids
FROM
    corpus_edits
GROUP BY
    transliteration_id,
    sign_no;


CREATE OR REPLACE PROCEDURE undo (
    v_edit_id integer, 
    v_schema text
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE

v_query text;

BEGIN
FOR v_query IN 
    SELECT edit_log_undo_query(transliteration_id, v_schema, entry_no, key_col, target, action, val_old)
    FROM edit_log JOIN edits USING (edit_id)
    WHERE 
        edit_id = v_edit_id
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
    v_timestamp timestamp, 
    v_schema text
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$

DECLARE

v_query text;

BEGIN
FOR v_query IN 
    SELECT edit_log_undo_query(transliteration_id, v_schema, entry_no, key_col, target, action, val_old) 
    FROM edit_log JOIN edits USING (edit_id)
    WHERE 
        transliteration_id = v_transliteration_id 
        AND timestamp > v_timestamp
    ORDER BY timestamp DESC, log_no DESC 
    LOOP
    RAISE INFO USING MESSAGE = v_query;
    DISCARD PLANS;
    EXECUTE v_query;
END LOOP;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE redo (
    v_edit_id integer, 
    v_schema text
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE

v_query text;

BEGIN
FOR v_query IN 
    SELECT edit_log_redo_query(transliteration_id, v_schema, entry_no, key_col, target, action, val) 
    FROM edit_log JOIN edits USING (edit_id)
    WHERE 
        edit_id = v_edit_id
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
    v_timestamp timestamp
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
    CALL revert_to(v_transliteration_id, v_timestamp, 'public');
    DELETE FROM edits WHERE transliteration_id = v_transliteration_id AND timestamp > v_timestamp;
END;
$BODY$;