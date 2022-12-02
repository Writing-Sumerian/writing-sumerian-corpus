CREATE TYPE log_data AS (
    transliteration_id integer,
    entry_no integer,
    target text,
    action text,
    query text
);

CREATE OR REPLACE FUNCTION adjust_key_col (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    key_col_to_adjust text,
    val integer,
    schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    ROWS 1
    LANGUAGE PLPGSQL
    AS 
$BODY$

DECLARE

entry_no_log integer := entry_no;

BEGIN

IF key_col = key_col_to_adjust THEN
    entry_no_log = entry_no_log + val;
END IF;

RETURN QUERY EXECUTE format(
    $$
    SELECT
        %1$s,
        %2$s,
        %3$L,
        'adjust',
        'SELECT adjust_key_col(%1$s, %2$s, ''%3$s'', ''%4$s'', ''%5$s'', %6$s, $1)'
    $$,
    transliteration_id,
    entry_no_log,
    target,
    key_col,
    key_col_to_adjust,
    -val);

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format(
    $$
    UPDATE %I.%I SET
        %3$I = -(%3$I + %4$s)
    WHERE
        transliteration_id = %5$s AND
        %6$I >= %7$s
    $$,
    schema,
    target,
    key_col_to_adjust,
    val,
    transliteration_id,
    key_col,
    entry_no
    );

EXECUTE format(
    $$
    UPDATE %I.%I SET
        %3$I = -%3$I
    WHERE
        transliteration_id = %4$s AND
        %3$I < 0
    $$,
    schema,
    target,
    key_col_to_adjust,
    transliteration_id);

RETURN;

END;
$BODY$;


CREATE OR REPLACE FUNCTION update_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    col text,
    value text,
    schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    ROWS 1
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN

RETURN QUERY EXECUTE format(
    $$
    SELECT
        %5$s,
        %6$s,
        %1$L,
        %4$L,
        format('SELECT update_entry(%%s, %%s, %%L, %%L, %%L, %%L, $1)', %5$s, %6$s, %1$L, %3$L, %4$L, %4$I)
    FROM
        %2$I.%1$I
    WHERE
        transliteration_id = %5$s AND
        %3$I = %6$s
    $$,
    target,
    schema,
    key_col,
    col,
    transliteration_id,
    entry_no);

EXECUTE format(
    $$
    UPDATE %I.%I SET
        %I = %L
    WHERE
        transliteration_id = %s AND
        %I = %s;
    $$,
    schema,
    target,
    col,
    value,
    transliteration_id,
    key_col,
    entry_no);

RETURN;

END;
$BODY$;


CREATE OR REPLACE FUNCTION insert_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    vals record,
    schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    ROWS 1
    LANGUAGE PLPGSQL
    AS 
$BODY$

BEGIN

RETURN QUERY EXECUTE format(
    $$
    SELECT
        %1$s,
        %2$s,
        %3$L,
        'insert',
        'SELECT delete_entry(%1$s, %s, ''%s'', ''%s'', $1)'
    $$,
    transliteration_id,
    entry_no,
    target,
    key_col);

SET CONSTRAINTS ALL DEFERRED;

PERFORM adjust_key_col(transliteration_id, entry_no, target, key_col, key_col, 1, schema);

EXECUTE format(
    $$
    INSERT INTO %1$I.%2$I
    SELECT (%L::%1$I.%2$I).*
    $$,
    schema,
    target,
    vals);

RETURN;

END;
$BODY$;


CREATE OR REPLACE FUNCTION delete_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    ROWS 1
    LANGUAGE PLPGSQL
    AS 
$BODY$

BEGIN

RETURN QUERY EXECUTE format(
    $$
    SELECT
        %4$s,
        %5$s,
        %1$L,
        'delete',
        format('SELECT insert_entry(%%s, %%s, %%L, %%L, %%L::%2$I.%1$I, $1)',
            %4$s,
            %5$s,
            %1$L,
            %3$L,
            %1$I)
    FROM
        %2$I.%1$I
    WHERE
        transliteration_id = %4$s AND
        %3$I = %5$s
    $$,
    target,
    schema,
    key_col,
    transliteration_id,
    entry_no);

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format(
    $$
    DELETE FROM %I.%I
    WHERE
        transliteration_id = %s AND
        %I = %s
    $$,
    schema,
    target,
    transliteration_id,
    key_col,
    entry_no);

PERFORM adjust_key_col(transliteration_id, entry_no, target, key_col, key_col, -1, schema);

RETURN;

END;
$BODY$;


CREATE OR REPLACE FUNCTION split_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    parent_target text,
    parent_key_col text,
    vals record,
    schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    ROWS 2
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE

parent_entry_no integer;

BEGIN

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format(
    $$
    SELECT %I 
    FROM %I.%I
    WHERE
        transliteration_id = %s AND
        %I = %s
    $$,
    parent_key_col,
    schema,
    target,
    transliteration_id,
    key_col,
    entry_no)
    INTO STRICT parent_entry_no;

RETURN QUERY SELECT * FROM insert_entry(transliteration_id, parent_entry_no, parent_target, parent_key_col, vals, schema);
RETURN QUERY SELECT * FROM adjust_key_col(transliteration_id, entry_no+1, target, key_col, parent_key_col, 1, schema);
RETURN;

END;
$BODY$;


CREATE OR REPLACE FUNCTION merge_entries (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    child_target text,
    child_key_col text,
    schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    ROWS 2
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE

child_entry_no integer;

BEGIN

EXECUTE format(
    $$
    SELECT
        min(%1$I)
    FROM
        %2$I.%3$I
    WHERE
        %4$I = %5$s
        AND transliteration_id = %6$s
    $$,
    child_key_col,
    schema,
    child_target,
    key_col,
    entry_no+1,
    transliteration_id
    )
    INTO child_entry_no;
RAISE INFO USING MESSAGE = child_entry_no;
SET CONSTRAINTS ALL DEFERRED;
RETURN QUERY SELECT * FROM adjust_key_col(transliteration_id, child_entry_no, child_target, child_key_col, key_col, -1, schema);
RETURN QUERY SELECT * FROM delete_entry(transliteration_id, entry_no, target, key_col, schema);
RETURN;

END;
$BODY$;


-- signs

CREATE OR REPLACE PROCEDURE update_sign (transliteration_id integer, sign_no integer, col text, value text, schema text, log boolean)
    LANGUAGE SQL 
    AS $$CALL update_entry(transliteration_id, sign_no, 'corpus', 'sign_no', col, value, schema, log);$$;

CREATE OR REPLACE PROCEDURE insert_sign (transliteration_id integer, sign_no integer, vals record, schema text, log boolean)
    LANGUAGE PLPGSQL
    AS $$BEGIN CALL insert_entry(transliteration_id, sign_no, 'corpus', 'sign_no', vals, schema, log); END;$$;

CREATE OR REPLACE PROCEDURE delete_sign (transliteration_id integer, sign_no integer, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL delete_entry(transliteration_id, sign_no, 'corpus', 'sign_no', schema, log);$$;


-- words

CREATE OR REPLACE PROCEDURE update_word (transliteration_id integer, word_no integer, col text, value text, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL update_entry(transliteration_id, word_no, 'words', 'word_no', col, value, schema, log);$$;


CREATE OR REPLACE PROCEDURE split_word (transliteration_id integer, sign_no integer, vals record, schema text, log boolean)
    LANGUAGE PLPGSQL
    AS $$BEGIN CALL split_entry(transliteration_id, sign_no, 'corpus','sign_no', 'words', 'word_no', vals, schema, log); END;$$;

CREATE OR REPLACE PROCEDURE merge_words (transliteration_id integer, word_no integer, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL merge_entries(transliteration_id, word_no, 'words', 'word_no', 'corpus', schema, log);$$;


-- compounds

CREATE OR REPLACE PROCEDURE update_compound (transliteration_id integer, compound_no integer, col text, value text, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL update_entry(transliteration_id, compound_no, 'compounds', 'compound_no', col, value, schema, log);$$;


CREATE OR REPLACE PROCEDURE split_compound (transliteration_id integer, sign_no integer, vals record, schema text, log boolean)
    LANGUAGE PLPGSQL
    AS $$BEGIN CALL split_entry(transliteration_id, sign_no, 'corpus','sign_no', 'compounds', 'compound_no', vals, schema, log); END;$$;

CREATE OR REPLACE PROCEDURE merge_compounds (transliteration_id integer, compound_no integer, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL merge_entries(transliteration_id, compound_no, 'compounds', 'compound_no', 'words', schema, log);$$;


-- lines

CREATE OR REPLACE PROCEDURE update_line (transliteration_id integer, line_no integer, col text, value text, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL update_entry(transliteration_id, line_no, 'lines', 'line_no', col, value, schema, log);$$;


CREATE OR REPLACE PROCEDURE split_line (transliteration_id integer, sign_no integer, vals record, schema text, log boolean)
    LANGUAGE PLPGSQL
    AS $$BEGIN CALL split_entry(transliteration_id, sign_no, 'corpus','sign_no', 'lines', 'line_no', vals, schema, log); END;$$;

CREATE OR REPLACE PROCEDURE merge_lines (transliteration_id integer, line_no integer, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL merge_entries(transliteration_id, line_no, 'lines', 'line_no', 'corpus', schema, log);$$;


-- blocks

CREATE OR REPLACE PROCEDURE update_block (transliteration_id integer, block_no integer, col text, value text, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL update_entry(transliteration_id, block_no, 'blocks', 'block_no', col, value, schema, log);$$;


CREATE OR REPLACE PROCEDURE split_block (transliteration_id integer, sign_no integer, vals record, schema text, log boolean)
    LANGUAGE PLPGSQL
    AS $$BEGIN CALL split_entry(transliteration_id, sign_no, 'corpus','sign_no', 'blocks', 'block_no', vals, schema, log); END;$$;

CREATE OR REPLACE PROCEDURE merge_blocks (transliteration_id integer, block_no integer, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL merge_entries(transliteration_id, block_no, 'blocks', 'block_no', 'lines', schema, log);$$;


-- surfaces

CREATE OR REPLACE PROCEDURE update_surface (transliteration_id integer, surface_no integer, col text, value text, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL update_entry(transliteration_id, surface_no, 'surfaces', 'surface_no', col, value, schema, log);$$;


CREATE OR REPLACE PROCEDURE split_surface (transliteration_id integer, sign_no integer, vals record, schema text, log boolean)
    LANGUAGE PLPGSQL
    AS $$BEGIN CALL split_entry(transliteration_id, sign_no, 'corpus','sign_no', 'surfaces', 'surface_no', vals, schema, log); END;$$;

CREATE OR REPLACE PROCEDURE merge_surfaces (transliteration_id integer, surface_no integer, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL merge_entries(transliteration_id, surface_no, 'surfaces', 'surface_no', 'blockss', schema, log);$$;


-- objects

CREATE OR REPLACE PROCEDURE update_object (transliteration_id integer, object_no integer, col text, value text, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL update_entry(transliteration_id, object_no, 'objects', 'object_no', col, value, schema, log);$$;


CREATE OR REPLACE PROCEDURE split_object (transliteration_id integer, sign_no integer, vals record, schema text, log boolean)
    LANGUAGE PLPGSQL
    AS $$BEGIN CALL split_entry(transliteration_id, sign_no, 'corpus','sign_no', 'objects', 'object_no', vals, schema, log); END;$$;

CREATE OR REPLACE PROCEDURE merge_objects (transliteration_id integer, object_no integer, schema text, log boolean)
    LANGUAGE SQL
    AS $$CALL merge_entries(transliteration_id, object_no, 'objects', 'object_no', 'surfaces', schema, log);$$;



-- general

CREATE OR REPLACE PROCEDURE delete_transliteration (transliteration_id integer, schema text)
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
t text;
BEGIN
FOREACH t IN ARRAY array['corpus', 'words', 'compounds', 'lines', 'blocks', 'surfaces', 'objects'] LOOP
    EXECUTE format($$DELETE FROM %I.%I WHERE transliteration_id = %s$$, schema, t, transliteration_id);
END LOOP;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE copy_transliteration (transliteration_id integer, source_schema text, target_schema text)
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
t text;
BEGIN
FOREACH t IN ARRAY array['corpus', 'words', 'compounds', 'lines', 'blocks', 'surfaces', 'objects'] LOOP
    EXECUTE format($$INSERT INTO %I.%I SELECT * FROM %I.%I WHERE transliteration_id = %s$$, source_schema, t, target_schema, t, transliteration_id);
END LOOP;
END;
$BODY$;