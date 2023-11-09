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



CREATE TABLE edits (
    edit_id BIGSERIAL PRIMARY KEY,
    transliteration_id integer REFERENCES transliterations(transliteration_id) ON DELETE CASCADE,
    timestamp timestamp,
    user_id text,
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