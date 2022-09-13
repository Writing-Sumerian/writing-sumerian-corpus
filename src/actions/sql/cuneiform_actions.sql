CREATE TABLE corpus_log (
    log_no bigserial PRIMARY KEY,
    transliteration_id integer REFERENCES transliterations(transliteration_id) ON DELETE CASCADE,
    timestamp timestamp,
    query text
);



CREATE OR REPLACE PROCEDURE adjust_key_col (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    key_col_to_adjust text,
    val integer,
    schema text,
    log boolean
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$

DECLARE

entry_no_log integer := entry_no;

BEGIN

IF log THEN

    IF key_col = key_col_to_adjust THEN
        entry_no_log = entry_no_log + val;
    END IF;

    EXECUTE format(
        $$
        INSERT INTO corpus_log (transliteration_id, timestamp, query)
        SELECT
            %1$s,
            CURRENT_TIMESTAMP,
            'CALL adjust_key_col(%1$s, %s, ''%s'', ''%s'', ''%s'', %s, $1, false)'
        $$,
        transliteration_id,
        entry_no_log,
        target,
        key_col,
        key_col_to_adjust,
        -val);
END IF;


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

END;
$BODY$;


CREATE OR REPLACE PROCEDURE update_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    col text,
    value text,
    schema text,
    log boolean
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN

IF log THEN
    EXECUTE format(
        $$
        INSERT INTO corpus_log (transliteration_id, timestamp, query)
        SELECT
            %5$s,
            CURRENT_TIMESTAMP,
            format('CALL update_entry(%%s, %%s, %%L, %%L, %%L, %%L, $1, false)', %5$s, %6$s, %1$L, %3$L, %4$L, %4$I)
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
END IF;

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

END;
$BODY$;


CREATE OR REPLACE PROCEDURE insert_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    vals record,
    schema text,
    log boolean
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$

BEGIN

IF log THEN
    EXECUTE format(
        $$
        INSERT INTO corpus_log (transliteration_id, timestamp, query)
        SELECT
            %1$s,
            CURRENT_TIMESTAMP,
            'CALL delete_entry(%1$s, %s, ''%s'', ''%s'', $1, false)'
        $$,
        transliteration_id,
        entry_no,
        target,
        key_col);
END IF;

SET CONSTRAINTS ALL DEFERRED;

CALL adjust_key_col(transliteration_id, entry_no, target, key_col, key_col, 1, schema, false);

EXECUTE format(
    $$
    INSERT INTO %1$I.%2$I
    SELECT (%L::%1$I.%2$I).*
    $$,
    schema,
    target,
    vals);

END;
$BODY$;


CREATE OR REPLACE PROCEDURE delete_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    schema text,
    log boolean
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$

BEGIN

IF log THEN
    EXECUTE format(
        $$
        INSERT INTO corpus_log (transliteration_id, timestamp, query)
        SELECT
            %4$s,
            CURRENT_TIMESTAMP,
            format('CALL insert_entry(%%s, %%s, %%L, %%L, %%L::%2$I.%1$I, $1, false)',
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
END IF;

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

CALL adjust_key_col(transliteration_id, entry_no, target, key_col, key_col, -1, schema, false);

END;
$BODY$;


CREATE OR REPLACE PROCEDURE split_entry (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    parent_target text,
    parent_key_col text,
    vals record,
    schema text,
    log boolean
    )
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

CALL insert_entry(transliteration_id, parent_entry_no, parent_target, parent_key_col, vals, schema, log);
CALL adjust_key_col(transliteration_id, entry_no+1, target, key_col, parent_key_col, 1, schema, log);

END;
$BODY$;


CREATE OR REPLACE PROCEDURE merge_entries (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    child_target text,
    schema text,
    log boolean
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN

SET CONSTRAINTS ALL DEFERRED;
CALL adjust_key_col(transliteration_id, entry_no+1, child_target, key_col, key_col, -1, schema, log);
CALL delete_entry(transliteration_id, entry_no, target, key_col, schema, log);

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


CREATE OR REPLACE PROCEDURE undo (
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
    SELECT query 
    FROM corpus_log 
    WHERE 
        transliteration_id = v_transliteration_id 
        AND timestamp >= v_timestamp
    ORDER BY log_no DESC 
    LOOP
    RAISE INFO USING MESSAGE = v_query;
    DISCARD PLANS;
    EXECUTE v_query USING v_schema;
END LOOP;
END;
$BODY$;