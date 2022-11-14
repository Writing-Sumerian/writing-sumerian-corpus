CREATE SCHEMA editor;

CALL create_corpus('editor');
CREATE TABLE editor.errors (
    transliteration_id integer,
    line integer,
    col integer,
    symbol text,
    message text
);

CREATE TYPE levenshtein_op AS ENUM ('NONE', 'INSERT', 'DELETE', 'UPDATE');
CREATE TYPE wagner_fischer_op AS (op levenshtein_op, pos integer);

CREATE OR REPLACE FUNCTION levenshtein(
    s anyarray,
    t anyarray,
    OUT cost integer,
    OUT ops wagner_fischer_op[])
    LANGUAGE 'plpgsql'

    COST 100
    STABLE 
AS $BODY$
DECLARE

    d integer[][] := array_fill(0, ARRAY[cardinality(s)+1, cardinality(t)+1]);
    o levenshtein_op[][] := array_fill('NONE'::levenshtein_op, ARRAY[cardinality(s)+1, cardinality(t)+1]);
    op levenshtein_op;

    k integer := cardinality(s)+1;
    l integer := cardinality(t)+1;

BEGIN
    FOR i IN 1..cardinality(s)+1 LOOP
        d[i][1] = i-1;
    END LOOP;
    FOR i IN 1..cardinality(t)+1 LOOP
        d[1][i] = i-1;
    END LOOP;

    FOR j IN 2..cardinality(t)+1 LOOP
        FOR i IN 2..cardinality(s)+1 LOOP
            op = 'NONE';
            cost = d[i-1][j-1];
            IF s[i-1] != t[j-1] THEN
                cost = cost+1;
                op = 'UPDATE';
            END IF;

            IF cost > d[i-1][j] + 1 THEN
                cost = d[i-1][j] + 1;
                op = 'DELETE';
            ELSIF cost > d[i][j-1] + 1 THEN
                cost = d[i][j-1] + 1;
                op = 'INSERT';
            END IF;

            d[i][j] = cost;
            o[i][j] = op;
        END LOOP;
    END LOOP;

    ops = ARRAY[]::wagner_fischer_op[];

    WHILE k != 1 AND l != 1 LOOP
        IF o[k][l] = 'DELETE' THEN
            ops = ROW('DELETE', l)::wagner_fischer_op||ops;
            k = k-1;
        ELSIF o[k][l] = 'INSERT' THEN
            ops = ROW('INSERT', l-1)::wagner_fischer_op||ops;
            l = l-1;
        ELSIF o[k][l] = 'UPDATE' THEN
            ops = ROW('UPDATE', l-1)::wagner_fischer_op||ops;
            k = k-1;
            l = l-1;
        ELSE
            k = k-1;
            l = l-1; 
        END IF;
    END LOOP;

    FOR i IN 1..k-1 LOOP
        ops = ROW('DELETE', 1)::wagner_fischer_op||ops;
    END LOOP;
    FOR j IN 1..l-1 LOOP
        ops = ROW('INSERT', 1)::wagner_fischer_op||ops;
    END LOOP;

    cost = d[array_length(s,1)+1][array_length(t,1)+1];
END;

$BODY$;


CREATE OR REPLACE PROCEDURE update_all_entries(
    transliteration_id integer,
    target text,
    key_col text,
    col text,
    source_schema text, 
    target_schema text
    )
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE

    entry_no integer;
    value text;

BEGIN

FOR entry_no, value IN EXECUTE format($$
    SELECT 
        %3$I, 
        a.%4$I::text
    FROM %5$I.%2$I a 
    JOIN %6$I.%2$I b USING (transliteration_id, %3$I) 
    WHERE transliteration_id = %1$s AND COALESCE(a.%4$I != b.%4$I, NOT (a.%4$I IS NULL AND b.%4$I IS NULL))$$,
    transliteration_id, target, key_col, col, source_schema, target_schema)
    LOOP

    CALL update_entry(transliteration_id, entry_no, target, key_col, col, value, target_schema, TRUE);

END LOOP;

END;
$BODY$;



CREATE OR REPLACE PROCEDURE split_merge_all_entries(
    transliteration_id integer,
    target text,
    child_target text,
    key_col text,
    child_key_col text,
    special_cols text[],
    normal_cols text[]
    )
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE

    rec             record;
    entry_no        integer;
    child_entry_no  integer;
    split           boolean;

    row_count       integer;

    col             text;
    special_cols_t  text[] := array[]::text[];
    normal_cols_t   text[] := array[]::text[];    

BEGIN

FOREACH col IN ARRAY special_cols LOOP
    special_cols_t = special_cols_t || ('COALESCE(b.' || quote_ident(col) || ', 0)');
END LOOP;
FOREACH col IN ARRAY normal_cols LOOP
    normal_cols_t = normal_cols_t || ('a.' || quote_ident(col));
END LOOP;

LOOP
    EXECUTE format($$
        SELECT 
            %1$I-1,
            a.%2$I,
            a.%2$I > b.%2$I
        FROM 
            editor.%3$I a 
            JOIN %3$I b USING (transliteration_id, %1$I)
        WHERE 
            a.transliteration_id = %4$s
            AND a.%2$I != b.%2$I
        ORDER BY %1$I LIMIT 1
        $$,
        child_key_col,
        key_col,
        child_target,
        transliteration_id)
    INTO
        child_entry_no,
        entry_no,
        split;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    EXIT WHEN row_count = 0;

    IF split THEN

        EXECUTE format($$
            SELECT 
                a.transliteration_id,
                a.%3$I,
                %5$s
                %6$s
            FROM 
                editor.%1$I a
                LEFT JOIN %1$I b ON a.transliteration_id = b.transliteration_id AND b.%3$I = %4$s-1
            WHERE
                a.transliteration_id = %2$s 
                AND a.%3$I = %4$s-1
            $$,
            target,
            transliteration_id,
            key_col,
            entry_no,
            COALESCE(NULLIF(array_to_string(special_cols_t, ','), '') || ',', ''),
            array_to_string(normal_cols_t, ',')
            )
            INTO STRICT rec;
        CALL split_entry(transliteration_id, child_entry_no, child_target, child_key_col, target, key_col, rec, 'public', true);
    ELSE
        CALL merge_entries(transliteration_id, entry_no, target, key_col, child_target, 'public', true);
    END IF;
END LOOP;

END;
$BODY$;


CREATE OR REPLACE PROCEDURE delete_empty_entries(
    transliteration_id integer,
    target text,
    child_target text,
    key_col text
    )
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE

    entry_no        integer;

BEGIN

FOR entry_no IN
    EXECUTE format(
        $$
        SELECT %1$I FROM (
            SELECT %1$I FROM %2$I WHERE transliteration_id = %4$s
            EXCEPT SELECT %1$I FROM %3$I WHERE transliteration_id = %4$s) _
            ORDER BY %1$I DESC
        $$,
        key_col,
        target,
        child_target,
        transliteration_id)
    LOOP
    CALL adjust_key_col(transliteration_id, entry_no+1, child_target, key_col, key_col, -1, 'public', true);
    CALL delete_entry(transliteration_id, entry_no, target, key_col, 'public', true);
END LOOP;

END;
$BODY$;



CREATE OR REPLACE PROCEDURE edit (
    v_schema text, 
    v_transliteration_id integer
    )
    LANGUAGE PLPGSQL
AS $BODY$

DECLARE

    op              wagner_fischer_op;
    ops             wagner_fischer_op[];
    rec             record;
    col             text;
    entry_no        integer;
    child_entry_no  integer;
    split           boolean;

BEGIN

    EXECUTE format(
        $$
        WITH
        a AS (
            SELECT 
                COALESCE(array_agg(COALESCE(value, glyphs, custom_value) ORDER BY sign_no), ARRAY[]::text[]) AS signs 
            FROM 
                corpus
                LEFT JOIN values USING (value_id) 
                LEFT JOIN value_variants ON main_variant_id = value_variant_id
                LEFT JOIN sign_variants_text USING (sign_variant_id)
            WHERE 
                corpus.transliteration_id = %2$s
        ),
        b AS (
            SELECT 
                COALESCE(array_agg(COALESCE(value, glyphs, custom_value) ORDER BY sign_no), ARRAY[]::text[]) AS signs 
            FROM 
                %1$I.corpus 
                LEFT JOIN values USING (value_id) 
                LEFT JOIN value_variants ON main_variant_id = value_variant_id
                LEFT JOIN sign_variants_text USING (sign_variant_id)
            WHERE 
                corpus.transliteration_id = %2$s
        )
        SELECT 
            (levenshtein(a.signs, b.signs)).ops
        FROM a, b
        $$,
        v_schema,
        v_transliteration_id)
        INTO ops;

    FOREACH op IN ARRAY ops LOOP
        IF (op).op = 'INSERT' THEN
            EXECUTE format(
                $$
                SELECT 
                    a.transliteration_id,
                    (op).pos-1,
                    COALESCE(b.line_no, 0),
                    COALESCE(b.word_no, 0),
                    a.custom_value,
                    a.value_id,
                    a.sign_variant_id,
                    a.properties,
                    a.stem,
                    a.condition,
                    a.crits,
                    a.comment,
                    a.newline,
                    a.inverted,
                    a.ligature
                FROM 
                    %I.corpus a
                    LEFT JOIN corpus b ON a.transliteration_id = b.transliteration_id AND b.sign_no = (op).pos-2
                WHERE
                    a.transliteration_id = %s AND a.sign_no = (op).pos-1
                $$,
                v_schema,
                v_transliteration_id),
                INTO rec;

            CALL insert_sign(transliteration_id, (op).pos-1, rec, 'public', true);
        ELSIF (op).op = 'DELETE' THEN
            CALL delete_sign(transliteration_id, (op).pos-1, 'public', true);
        END IF;
    END LOOP;

    FOREACH col IN ARRAY array['custom_value', 'value_id', 'sign_variant_id', 'properties', 'stem', 
                               'condition', 'crits', 'comment', 'newline', 'inverted', 'ligature'] LOOP
        CALL update_all_entries(v_transliteration_id, 'corpus', 'sign_no', col, v_schema, 'public');
    END LOOP;

    CALL delete_empty_entries(v_transliteration_id, 'words', 'corpus', 'word_no');
    CALL split_merge_all_entries(v_transliteration_id, 'words', 'corpus', 'word_no', 'sign_no', array['compound_no'], array['capitalized']);
    CALL update_all_entries(v_transliteration_id, 'words', 'word_no', 'capitalized', v_schema, 'public');

    

    CALL delete_empty_entries(v_transliteration_id, 'compounds', 'words', 'compound_no');
    CALL split_merge_all_entries(v_transliteration_id, 'compounds', 'words', 'compound_no', 'word_no', array[]::text[], array['pn_type', 'language', 'compound_comment']);
    FOREACH col IN ARRAY array['pn_type', 'language', 'compound_comment'] LOOP
        CALL update_all_entries(v_transliteration_id, 'compounds', 'compound_no', col, v_schema, 'public');
    END LOOP;

    CALL delete_empty_entries(v_transliteration_id, 'lines', 'corpus', 'line_no');
    CALL split_merge_all_entries(v_transliteration_id, 'lines', 'corpus', 'line_no', 'sign_no', array['block_no'], array['line', 'line_comment']);
    FOREACH col IN ARRAY array['line', 'line_comment'] LOOP
        CALL update_all_entries(v_transliteration_id, 'lines', 'line_no', col, v_schema, 'public');
    END LOOP;

    CALL delete_empty_entries(v_transliteration_id, 'blocks', 'lines', 'block_no');
    CALL split_merge_all_entries(v_transliteration_id, 'blocks', 'lines', 'block_no', 'line_no', array['surface_no'], array['block_type', 'block_data', 'block_comment']);
    FOREACH col IN ARRAY array['block_type', 'block_data', 'block_comment'] LOOP
        CALL update_all_entries(v_transliteration_id, 'blocks', 'block_no', col, v_schema, 'public');
    END LOOP;

    CALL delete_empty_entries(v_transliteration_id, 'surfaces', 'blocks', 'surface_no');
    CALL split_merge_all_entries(v_transliteration_id, 'surfaces', 'blocks', 'surface_no', 'block_no', array['object_no'], array['surface_type', 'surface_data', 'surface_comment']);
    FOREACH col IN ARRAY array['surface_type', 'surface_data', 'surface_comment'] LOOP
        CALL update_all_entries(v_transliteration_id, 'surfaces', 'surface_no', col, v_schema, 'public');
    END LOOP;

    CALL delete_empty_entries(v_transliteration_id, 'objects', 'surfaces', 'object_no');
    CALL split_merge_all_entries(v_transliteration_id, 'objects', 'surfaces', 'object_no', 'surface_no', array[]::text[], array['object_type', 'object_data', 'object_comment']);
    FOREACH col IN ARRAY array['object_type', 'object_data', 'object_comment'] LOOP
        CALL update_all_entries(v_transliteration_id, 'objects', 'object_no', col, v_schema, 'public');
    END LOOP;

END;

$BODY$;


CREATE OR REPLACE PROCEDURE edit_transliteration(
    code text, 
    transliteration_id integer,
    language language,
    stemmed boolean
    )
    LANGUAGE PLPGSQL
AS $BODY$

BEGIN

    CALL parse(code, 'editor', language, stemmed, transliteration_id);
    CALL edit('editor', transliteration_id);
    CALL delete_transliteration(transliteration_id, 'editor');

END;

$BODY$;