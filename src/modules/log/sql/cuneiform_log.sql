CREATE OR REPLACE FUNCTION edit_log_redo_query (
        v_transliteration_id integer,
        v_schema text,
        v_entry_no integer,
        v_key_col text,
        v_target text,
        v_action text,
        v_val text
    )
    RETURNS text
    IMMUTABLE
    LANGUAGE PLPGSQL
AS $BODY$
DECLARE

v_ops text[];

BEGIN

SELECT string_to_array(v_action, ' ') INTO v_ops;

CASE v_ops[1]
    WHEN 'update' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.update_entry(%s, %s, %L, %L, %L, %L, %L)', 
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_ops[2], v_val, v_schema);
    WHEN 'adjust' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.adjust_key_col(%s, %s, %L, %L, %L, %L, %L)',
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_ops[2], v_val, v_schema);
    WHEN 'shift' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.shift_key_col(%s, %s, %L, %L, %L, %L)',
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_val, v_schema);
    WHEN 'insert' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.insert_entry(%1$s, %2$s, %3$L, %4$L, %5$L::%6$I.%3$I, %6$L)'
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_val, v_schema);
    WHEN 'delete' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.delete_entry(%s, %s, %L, %L, %L)',
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_schema);
END CASE;
END;
$BODY$;



CREATE OR REPLACE FUNCTION edit_log_undo_query (
        v_transliteration_id integer,
        v_schema text,
        v_entry_no integer,
        v_key_col text,
        v_target text,
        v_action text,
        v_val_old text
    )
    RETURNS text
    IMMUTABLE
    LANGUAGE PLPGSQL
AS $BODY$
DECLARE

v_ops text[];

BEGIN

SELECT string_to_array(v_action, ' ') INTO v_ops;

CASE v_ops[1]
    WHEN 'update' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.update_entry(%s, %s, %L, %L, %L, %L, %L)', 
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_ops[2], v_val_old, v_schema);
    WHEN 'adjust' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.adjust_key_col(%s, %s, %L, %L, %L, %L, %L)',
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_ops[2], v_val_old, v_schema);
    WHEN 'shift' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.shift_key_col(%s, %s, %L, %L, %L, %L)',
            v_transliteration_id, v_entry_no-v_val_old::integer, v_target, v_key_col, v_val_old, v_schema);
    WHEN 'insert' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.delete_entry(%s, %s, %L, %L, %L)',
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_schema);
    WHEN 'delete' THEN
        RETURN format(
            'SELECT @extschema:cuneiform_actions@.insert_entry(%1$s, %2$s, %3$L, %4$L, %5$L::%6$I.%3$I, %6$L)',
            v_transliteration_id, v_entry_no, v_target, v_key_col, v_val_old, v_schema);
END CASE;
END;
$BODY$;



CREATE TYPE log_agg_state_type AS (
    id integer,
    edit_nos integer[]
);


CREATE OR REPLACE FUNCTION log_agg_sfunc (
        v_state log_agg_state_type,
        v_edit_no integer,
        v_action text,
        v_id integer,
        v_value text)
    RETURNS log_agg_state_type
    LANGUAGE SQL
    COST 100
    IMMUTABLE 
BEGIN ATOMIC
SELECT
    CASE
        WHEN v_action = 'insert' AND (v_state).id > v_id THEN ROW((v_state).id-1, (v_state).edit_nos)::log_agg_state_type
        WHEN v_action = 'insert' AND (v_state).id = v_id THEN ROW(null, (v_state).edit_nos || v_edit_no)::log_agg_state_type
        WHEN v_action = 'delete' AND (v_state).id >= v_id THEN ROW((v_state).id+1, (v_state).edit_nos)::log_agg_state_type
        WHEN v_action = 'shift' AND (v_state).id >= v_id THEN ROW((v_state).id+v_value::integer, (v_state).edit_nos)::log_agg_state_type
        WHEN v_action = 'update' AND (v_state).id = v_id THEN ROW((v_state).id, (v_state).edit_nos || v_edit_no)::log_agg_state_type
        WHEN v_action IS NULL THEN ROW(v_id, ARRAY[]::integer[])::log_agg_state_type -- init
        ELSE v_state
    END;
END;

CREATE OR REPLACE FUNCTION log_agg_finalfunc (
        v_state log_agg_state_type
    )
    RETURNS integer[]
    LANGUAGE SQL
    COST 100
    IMMUTABLE 
BEGIN ATOMIC
SELECT (v_state).edit_nos;
END;


CREATE OR REPLACE AGGREGATE log_agg (v_edit_no integer, v_action text, v_id integer, v_value text) (
    stype = log_agg_state_type,
    sfunc = log_agg_sfunc,
    finalfunc = log_agg_finalfunc
);