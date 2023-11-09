CREATE TYPE log_data AS (
    transliteration_id integer,
    entry_no integer,
    key_col text,
    target text,
    action text,
    val text,
    val_old text
);


-- change value of a key column based the table's key column (do not use to change the table's key column itself!)
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

BEGIN

RETURN QUERY EXECUTE format(
    $$
    SELECT
        %1$s,
        %2$s,
        %3$L,
        %4$L,
        'adjust %5$s',
        %6$L,
        %7$L
    $$,
    transliteration_id,
    entry_no,
    key_col,
    target,
    key_col_to_adjust,
    val,
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


-- change value of a key column based on the key column itself
CREATE OR REPLACE FUNCTION shift_key_col (
    transliteration_id integer,
    entry_no integer,
    target text,
    key_col text,
    val integer,
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
        %4$L,
        'shift',
        %5$L,
        %6$L
    $$,
    transliteration_id,
    entry_no,
    key_col,
    target,
    val,
    -val);

SET CONSTRAINTS ALL DEFERRED;

EXECUTE format(
    $$
    UPDATE %I.%I SET
        %3$I = -(%3$I + %4$s)
    WHERE
        transliteration_id = %5$s AND
        %3$I >= %6$s
    $$,
    schema,
    target,
    key_col,
    val,
    transliteration_id,
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
    key_col,
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
        %1$s,
        %2$s,
        %3$L,
        %4$L,
        'update %5$s',
        %6$L,
        %5$I::text
    FROM
        %7$I.%4$I
    WHERE
        transliteration_id = %1$s AND
        %3$I = %2$s
    $$,
    transliteration_id,
    entry_no,
    key_col,
    target,
    col,
    value,
    schema);

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
        %4$L,
        'insert',
        %5$L,
        NULL
    $$,
    transliteration_id,
    entry_no,
    key_col,
    target,
    vals);

SET CONSTRAINTS ALL DEFERRED;

PERFORM shift_key_col(transliteration_id, entry_no, target, key_col, 1, schema);

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
        %1$s,
        %2$s,
        %3$L,
        %4$L,
        'delete',
        NULL,
        %4$I::%5$I.%4$I::text
    FROM
        %5$I.%4$I
    WHERE
        transliteration_id = %1$s AND
        %3$I = %2$s
    $$,
    transliteration_id,
    entry_no,
    key_col,
    target,
    schema);

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

PERFORM shift_key_col(transliteration_id, entry_no, target, key_col, -1, schema);

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


-- general

CREATE OR REPLACE PROCEDURE delete_transliteration (transliteration_id integer, schema text)
    LANGUAGE PLPGSQL
    AS 
$BODY$
DECLARE
t text;
BEGIN
FOREACH t IN ARRAY array['corpus', 'words', 'compounds', 'lines', 'blocks', 'surfaces', 'sections'] LOOP
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
FOREACH t IN ARRAY array['sections', 'surfaces', 'blocks', 'lines', 'compounds', 'words', 'corpus'] LOOP
    EXECUTE format($$INSERT INTO %I.%I SELECT * FROM %I.%I WHERE transliteration_id = %s$$, target_schema, t, source_schema, t, transliteration_id);
END LOOP;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE convert_transliteration (transliteration_id integer, source_schema text, target_schema text)
    LANGUAGE PLPGSQL
AS $BODY$
BEGIN

EXECUTE format($$insert into %1$I.surfaces select transliteration_id_new, row_number() over (partition by surfaces.transliteration_id, object_no order by surface_no)-1, surface_type, surface_data, surface_comment from %2$I.surfaces join transliterations_cor using (transliteration_id, object_no) WHERE transliteration_id = %3$s$$, target_schema, source_schema, transliteration_id);

EXECUTE format($$insert into %1$I.blocks select transliteration_id_new, row_number() over (partition by surfaces.transliteration_id, object_no order by block_no)-1, surface_no - min(surface_no) over (partition by surfaces.transliteration_id, object_no order by block_no), block_type, block_data, block_comment from %2$I.blocks join %2$I.surfaces using (transliteration_id, surface_no) join transliterations_cor using (transliteration_id, object_no) WHERE transliteration_id = %3$s$$, target_schema, source_schema, transliteration_id);

EXECUTE format($$insert into %1$I.lines select transliteration_id_new, row_number() over (partition by surfaces.transliteration_id, object_no order by line_no)-1, block_no - min(block_no) over (partition by surfaces.transliteration_id, object_no), line, line_comment from %2$I.lines join %2$I.blocks using (transliteration_id, block_no) join %2$I.surfaces using (transliteration_id, surface_no) join transliterations_cor using (transliteration_id, object_no) WHERE transliteration_id = %3$s$$, target_schema, source_schema, transliteration_id);

EXECUTE format($$
WITH a AS (
SELECT corpus.transliteration_id,
    surfaces.object_no,
    compounds.section_no
   FROM corpus
     JOIN %2$I.words USING (transliteration_id, word_no)
     JOIN %2$I.compounds USING (transliteration_id, compound_no)
     JOIN %2$I.sections USING (transliteration_id, section_no)
     JOIN %2$I.lines USING (transliteration_id, line_no)
     JOIN %2$I.blocks USING (transliteration_id, block_no)
     JOIN %2$I.surfaces USING (transliteration_id, surface_no)
  GROUP BY corpus.transliteration_id, surfaces.object_no, compounds.section_no
)
insert into %1$I.sections select transliteration_id_new, row_number() over (partition by sections.transliteration_id, object_no order by section_no)-1, section_name, composition_id, witness_type from %2$I.sections join a using (transliteration_id, section_no) join transliterations_cor using (transliteration_id, object_no) WHERE transliteration_id = %3$s
$$,
target_schema, source_schema, transliteration_id);

EXECUTE format($$
WITH a AS (
SELECT corpus.transliteration_id,
    surfaces.object_no,
    words.compound_no
   FROM corpus
     JOIN %2$I.words USING (transliteration_id, word_no)
     JOIN %2$I.compounds USING (transliteration_id, compound_no)
     JOIN %2$I.lines USING (transliteration_id, line_no)
     JOIN %2$I.blocks USING (transliteration_id, block_no)
     JOIN %2$I.surfaces USING (transliteration_id, surface_no)
  GROUP BY corpus.transliteration_id, surfaces.object_no, words.compound_no
)
insert into %1$I.compounds select transliteration_id_new, row_number() over (partition by compounds.transliteration_id, object_no order by compound_no)-1, pn_type, language, section_no - min(section_no) over (partition by compounds.transliteration_id, object_no), compound_comment from %2$I.compounds join a using (transliteration_id, compound_no) join transliterations_cor using (transliteration_id, object_no) WHERE transliteration_id = %3$s
$$,
target_schema, source_schema, transliteration_id);

EXECUTE format($$
WITH a AS (
SELECT corpus.transliteration_id,
    surfaces.object_no,
    words.compound_no
   FROM corpus
     JOIN %2$I.words USING (transliteration_id, word_no)
     JOIN %2$I.compounds USING (transliteration_id, compound_no)
     JOIN %2$I.lines USING (transliteration_id, line_no)
     JOIN %2$I.blocks USING (transliteration_id, block_no)
     JOIN %2$I.surfaces USING (transliteration_id, surface_no)
  GROUP BY corpus.transliteration_id, surfaces.object_no, words.compound_no
)
insert into %1$I.words select transliteration_id_new, row_number() over (partition by words.transliteration_id, object_no order by word_no)-1, compound_no - min(compound_no) over (partition by words.transliteration_id, object_no), capitalized from %2$I.words join a using (transliteration_id, compound_no) join transliterations_cor using (transliteration_id, object_no) WHERE transliteration_id = %3$s
$$,
target_schema, source_schema, transliteration_id);

EXECUTE format($$
insert into %1$I.corpus select transliteration_id_new, row_number() over (partition by surfaces.transliteration_id, object_no order by sign_no)-1, line_no - min(line_no) over (partition by surfaces.transliteration_id, object_no), word_no - min(word_no) over (partition by surfaces.transliteration_id, object_no), value_id, sign_variant_id, custom_value,  type, indicator_type, phonographic, stem, condition, crits, comment, newline, inverted, ligature from %2$I.corpus join %2$I.lines using (transliteration_id, line_no) join %2$I.blocks using (transliteration_id, block_no) join %2$I.surfaces using (transliteration_id, surface_no) join transliterations_cor using (transliteration_id, object_no) WHERE transliteration_id = %3$s
$$,
target_schema, source_schema, transliteration_id);

END;
$BODY$;