CREATE OR REPLACE FUNCTION edit_log_redo_query (
        transliteration_id integer,
        schema text,
        entry_no integer,
        key_col text,
        target text,
        action text,
        val text
    )
    RETURNS text
    IMMUTABLE
    LANGUAGE PLPGSQL
AS $BODY$
DECLARE

ops text[];

BEGIN

SELECT string_to_array(action, ' ') INTO ops;

CASE ops[1]
    WHEN 'update' THEN
        RETURN format(
            'SELECT update_entry(%s, %s, %L, %L, %L, %L, %L)', 
            transliteration_id, entry_no, target, key_col, ops[2], val, schema);
    WHEN 'adjust' THEN
        RETURN format(
            'SELECT adjust_key_col(%s, %s, %L, %L, %L, %L, %L)',
            transliteration_id, entry_no, target, key_col, ops[2], val, schema);
    WHEN 'shift' THEN
        RETURN format(
            'SELECT shift_key_col(%s, %s, %L, %L, %L, %L)',
            transliteration_id, entry_no, target, key_col, val, schema);
    WHEN 'insert' THEN
        RETURN format(
            'SELECT insert_entry(%1$s, %2$s, %3$L, %4$L, %5$L::%6$I.%3$I, %6$L)'
            transliteration_id, entry_no, target, key_col, val, schema);
    WHEN 'delete' THEN
        RETURN format(
            'SELECT delete_entry(%s, %s, %L, %L, %L)',
            transliteration_id, entry_no, target, key_col, schema);
END CASE;
END;
$BODY$;



CREATE OR REPLACE FUNCTION edit_log_undo_query (
        transliteration_id integer,
        schema text,
        entry_no integer,
        key_col text,
        target text,
        action text,
        val_old text
    )
    RETURNS text
    IMMUTABLE
    LANGUAGE PLPGSQL
AS $BODY$
DECLARE

ops text[];

BEGIN

SELECT string_to_array(action, ' ') INTO ops;

CASE ops[1]
    WHEN 'update' THEN
        RETURN format(
            'SELECT update_entry(%s, %s, %L, %L, %L, %L, %L)', 
            transliteration_id, entry_no, target, key_col, ops[2], val_old, schema);
    WHEN 'adjust' THEN
        RETURN format(
            'SELECT adjust_key_col(%s, %s, %L, %L, %L, %L, %L)',
            transliteration_id, entry_no, target, key_col, ops[2], val_old, schema);
    WHEN 'shift' THEN
        RETURN format(
            'SELECT shift_key_col(%s, %s, %L, %L, %L, %L)',
            transliteration_id, entry_no-val_old::integer, target, key_col, val_old, schema);
    WHEN 'insert' THEN
        RETURN format(
            'SELECT delete_entry(%s, %s, %L, %L, %L)',
            transliteration_id, entry_no, target, key_col, schema);
    WHEN 'delete' THEN
        RETURN format(
            'SELECT insert_entry(%1$s, %2$s, %3$L, %4$L, %5$L::%6$I.%3$I, %6$L)',
            transliteration_id, entry_no, target, key_col, val_old, schema);
END CASE;
END;
$BODY$;



CREATE TYPE log_agg_state_type AS (
    id integer,
    edit_id integer
);


CREATE OR REPLACE FUNCTION log_agg_sfunc (
    state log_agg_state_type,
    edit_id integer,
    action text,
    id integer,
    value text)
    RETURNS log_agg_state_type
    LANGUAGE SQL
    COST 100
    IMMUTABLE 
AS $BODY$
SELECT
    CASE
        WHEN action = 'insert' AND (state).id > id THEN ROW((state).id-1, (state).edit_id)::log_agg_state_type
        WHEN action = 'insert' AND (state).id = id THEN ROW(null, COALESCE((state).edit_id, edit_id))::log_agg_state_type
        WHEN action = 'delete' AND (state).id >= id THEN ROW((state).id+1, (state).edit_id)::log_agg_state_type
        WHEN action = 'adjust' AND (state).id >= id THEN ROW((state).id+value::integer, (state).edit_id)::log_agg_state_type
        WHEN action = 'update' AND (state).id = id THEN ROW((state).id, COALESCE((state).edit_id, edit_id))::log_agg_state_type
        WHEN action IS NULL THEN ROW(id, NULL)::log_agg_state_type -- init
        ELSE state
    END;
$BODY$;

CREATE OR REPLACE FUNCTION log_agg_finalfunc (
    state log_agg_state_type
    )
    RETURNS integer
    LANGUAGE SQL
    COST 100
    IMMUTABLE 
AS $BODY$
SELECT (state).edit_id;
$BODY$;


CREATE OR REPLACE AGGREGATE log_agg (edit_id integer, action text, id integer, value text) (
    stype = log_agg_state_type,
    sfunc = log_agg_sfunc,
    finalfunc = log_agg_finalfunc
);


CREATE OR REPLACE VIEW corpus_modified AS
WITH corpus_edits AS (
    SELECT
        transliteration_id,
        sign_no,
        edit_id::integer,
        log_no,
        entry_no,
        split_part(action, ' ', 1) AS action,
        val
    FROM 
        new.edit_log 
        JOIN new.edits USING (edit_id)
        JOIN new.corpus USING (transliteration_id)
    WHERE
        target = 'corpus'
    UNION ALL
    SELECT
        transliteration_id,
        sign_no,
        NULL,
        2147483646,
        sign_no,
        NULL,
        NULL
    FROM new.corpus
)
SELECT
    transliteration_id,
    sign_no,
    log_agg(edit_id, action, entry_no, val ORDER BY log_no DESC)
FROM
    corpus_edits
GROUP BY
    transliteration_id,
    sign_no;