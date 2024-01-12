CREATE TABLE edits (
    edit_id BIGSERIAL PRIMARY KEY,
    transliteration_id integer REFERENCES transliterations(transliteration_id) ON DELETE CASCADE,
    timestamp timestamp,
    user_id integer,
    internal boolean
);

CREATE TABLE edit_log (
    edit_id integer REFERENCES edits (edit_id) ON DELETE CASCADE,
    log_no integer,
    entry_no integer,
    key_col text,
    target text,
    action text,
    val text,
    val_old text,
    PRIMARY KEY (edit_id, log_no)
);


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