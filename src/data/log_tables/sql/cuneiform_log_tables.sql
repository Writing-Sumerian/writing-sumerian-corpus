CREATE TABLE edits (
    edit_id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    transliteration_id integer REFERENCES @extschema:cuneiform_corpus@.transliterations(transliteration_id) ON DELETE CASCADE,
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


SELECT pg_catalog.pg_extension_config_dump('@extschema@.edits', '');
SELECT pg_catalog.pg_extension_config_dump('@extschema@.edit_log', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('@extschema@.edits', 'edit_id'), '');


CREATE OR REPLACE PROCEDURE load_log (path text)
    LANGUAGE PLPGSQL
    AS $BODY$

BEGIN

EXECUTE format('COPY @extschema@.edits(edit_id, transliteration_id, timestamp, user_id, internal) FROM %L CSV NULL ''\N''', path || 'edits.csv');
EXECUTE format('COPY @extschema@.edit_log(edit_id, log_no, entry_no, key_col, target, action, val, val_old) FROM %L CSV NULL ''\N''', path || 'edit_log.csv');

PERFORM setval(pg_get_serial_sequence('@extschema@.edits', 'edit_id'), max(edit_id)) FROM edits;

END
$BODY$;
