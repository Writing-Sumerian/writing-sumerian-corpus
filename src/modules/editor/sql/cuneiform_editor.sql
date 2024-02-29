CREATE TYPE levenshtein_op AS ENUM ('NONE', 'INSERT', 'DELETE', 'UPDATE');
CREATE TYPE wagner_fischer_op AS (op levenshtein_op, pos integer);

CREATE OR REPLACE FUNCTION levenshtein (
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


CREATE OR REPLACE FUNCTION update_all_entries (
    transliteration_id integer,
    target text,
    key_col text,
    col text,
    source_schema text, 
    target_schema text
    )
    RETURNS SETOF log_data
    VOLATILE
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

    RETURN QUERY SELECT * FROM update_entry(transliteration_id, entry_no, target, key_col, col, value, target_schema);

END LOOP;

RETURN;

END;
$BODY$;


CREATE OR REPLACE FUNCTION update_all_entries (
    transliteration_id integer,
    target text,
    key_col text,
    columns text[],
    special_col boolean[],
    source_schema text, 
    target_schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE

    i integer;

BEGIN

FOR i IN 1..array_length(columns, 1) LOOP
    IF NOT special_col[i] THEN
        RETURN QUERY SELECT * FROM update_all_entries(transliteration_id, target, key_col, columns[i], source_schema, target_schema);
    END IF;
END LOOP;

RETURN;

END;
$BODY$;


CREATE OR REPLACE FUNCTION split_merge_all_entries (
    transliteration_id integer,
    target text,
    child_target text,
    key_col text,
    child_key_col text,
    columns text[],
    special_col boolean[],
    source_schema text, 
    target_schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE

    rec             record;
    entry_no        integer;
    child_entry_no  integer;
    split           boolean;

    row_count       integer;

    col             text;
    cols_t          text[] := array[]::text[];
    i               integer;    

BEGIN

FOR i IN 1..array_length(columns, 1) LOOP
    IF special_col[i] THEN
        cols_t = cols_t || ('b.' || quote_ident(columns[i]));
    ELSE
        cols_t = cols_t || ('a.' || quote_ident(columns[i]));
    END IF;
END LOOP;

LOOP
    EXECUTE format($$
        SELECT 
            %1$I-1,
            a.%2$I,
            a.%2$I > b.%2$I
        FROM 
            %6$I.%3$I a 
            JOIN %5$I.%3$I b USING (transliteration_id, %1$I)
        WHERE 
            a.transliteration_id = %4$s
            AND a.%2$I != b.%2$I
        ORDER BY %1$I LIMIT 1
        $$,
        child_key_col,
        key_col,
        child_target,
        transliteration_id,
        target_schema,
        source_schema)
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
            FROM 
                %7$s.%1$I a
                LEFT JOIN %6$s.%1$I b ON a.transliteration_id = b.transliteration_id AND b.%3$I = %4$s-1
            WHERE
                a.transliteration_id = %2$s 
                AND a.%3$I = %4$s-1
            $$,
            target,
            transliteration_id,
            key_col,
            entry_no,
            array_to_string(cols_t, ','),
            target_schema,
            source_schema
            )
            INTO STRICT rec;
        RETURN QUERY SELECT * FROM split_entry(transliteration_id, child_entry_no, child_target, child_key_col, target, key_col, rec, target_schema);
    ELSE
        RETURN QUERY SELECT * FROM merge_entries(transliteration_id, entry_no, target, key_col, child_target, child_key_col, target_schema);
    END IF;
END LOOP;

END;
$BODY$;


CREATE OR REPLACE FUNCTION align_sections (
        v_transliteration_id integer,
        v_source_schema text, 
        v_target_schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE

v_max_section_no_target integer;
v_compound_no integer;
v_section_no_diff integer;
v_row_count integer;

BEGIN

EXECUTE format($$
    SELECT COALESCE(max(section_no), -1) FROM %2$I.sections WHERE transliteration_id = %1$s
    $$,
    v_transliteration_id,
    v_target_schema)
INTO v_max_section_no_target;

RETURN QUERY EXECUTE format($$
    SELECT (insert_entry).* FROM (
        SELECT 
            insert_entry(
                transliteration_id, 
                section_no, 
                'sections', 
                'section_no', 
                sections, 
                %2$L
            ) 
        FROM 
            %3$I.sections 
        WHERE 
            transliteration_id = %1$s
            AND section_no > %4$s) _
    $$,
    v_transliteration_id,
    v_target_schema,
    v_source_schema,
    v_max_section_no_target);

LOOP
    EXECUTE format($$
        SELECT 
            compound_no,
            b.section_no - a.section_no
        FROM 
            %2$I.compounds a 
            JOIN %3$I.compounds b USING (transliteration_id, compound_no)
        WHERE 
            a.transliteration_id = %1$s
            AND a.section_no != b.section_no
        ORDER BY compound_no LIMIT 1
        $$,
        v_transliteration_id,
        v_target_schema,
        v_source_schema)
    INTO
        v_compound_no,
        v_section_no_diff;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    EXIT WHEN v_row_count = 0;

    RETURN QUERY SELECT * FROM adjust_key_col(v_transliteration_id, v_compound_no, 'compounds', 'compound_no', 'section_no', v_section_no_diff, v_target_schema);

END LOOP;
RETURN;
END;
$BODY$;


CREATE OR REPLACE FUNCTION delete_empty_entries (
    transliteration_id integer,
    target text,
    child_target text,
    key_col text,
    target_schema text
    )
    RETURNS SETOF log_data
    VOLATILE
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE

    entry_no        integer;

BEGIN

FOR entry_no IN
    EXECUTE format(
        $$
        SELECT %1$I FROM (
            SELECT %1$I FROM %5$I.%2$I WHERE transliteration_id = %4$s
            EXCEPT SELECT %1$I FROM %5$I.%3$I WHERE transliteration_id = %4$s) _
            ORDER BY %1$I DESC
        $$,
        key_col,
        target,
        child_target,
        transliteration_id,
        target_schema)
    LOOP
    RETURN QUERY SELECT * FROM shift_key_col(transliteration_id, entry_no+1, child_target, key_col, -1, target_schema);
    RETURN QUERY SELECT * FROM delete_entry(transliteration_id, entry_no, target, key_col, target_schema);
END LOOP;

END;
$BODY$;


CREATE OR REPLACE FUNCTION edit (
    v_source_schema text, 
    v_target_schema text,
    v_transliteration_id integer
    )
    RETURNS SETOF log_data
    VOLATILE
    LANGUAGE PLPGSQL
AS $BODY$

DECLARE

    op      wagner_fischer_op;
    ops     wagner_fischer_op[];
    rec     record;
    col     text;

    v_word_no   integer;
    v_line_no   integer;

    word_columns          text[]      := '{compound_no, capitalized}';
    word_special_col      boolean[]   := '{t,f}';
    word_noupdate_col     boolean[]   := '{t,f}';
    compound_columns      text[]      := '{pn_type, language, section_no, compound_comment}';
    compound_special_col  boolean[]   := '{f,f,f,f}';
    compound_noupdate_col boolean[]   := '{f,f,f,f}';
    line_columns          text[]      := '{block_no, line, line_comment}';
    line_special_col      boolean[]   := '{t,f,f}';
    block_columns         text[]      := '{surface_no, block_type, block_data, block_comment}';
    block_special_col     boolean[]   := '{t,f,f,f}';
    surface_columns       text[]      := '{surface_type, surface_data, surface_comment}';
    surface_special_col   boolean[]   := '{f,f,f}';
    section_columns       text[]      := '{section_name, composition_id}';
    section_special_col   boolean[]   := '{f,f}';

BEGIN

    EXECUTE format(
        $$
        WITH
        a AS (
            SELECT 
                COALESCE(array_agg(COALESCE(value, glyphs, custom_value) ORDER BY sign_no), ARRAY[]::text[]) AS signs 
            FROM 
                %2$I.corpus
                LEFT JOIN values USING (value_id) 
                LEFT JOIN value_variants ON main_variant_id = value_variant_id
                LEFT JOIN sign_variants_composition USING (sign_variant_id)
            WHERE 
                corpus.transliteration_id = %3$s
        ),
        b AS (
            SELECT 
                COALESCE(array_agg(COALESCE(value, glyphs, custom_value) ORDER BY sign_no), ARRAY[]::text[]) AS signs 
            FROM 
                %1$I.corpus 
                LEFT JOIN values USING (value_id) 
                LEFT JOIN value_variants ON main_variant_id = value_variant_id
                LEFT JOIN sign_variants_composition USING (sign_variant_id)
            WHERE 
                corpus.transliteration_id = %3$s
        )
        SELECT 
            (levenshtein(a.signs, b.signs)).ops
        FROM a, b
        $$,
        v_source_schema,
        v_target_schema,
        v_transliteration_id)
        INTO ops;

    FOREACH op IN ARRAY ops LOOP
        IF (op).op = 'INSERT' THEN

            EXECUTE format(
                $$
                SELECT
                    CASE 
                        WHEN COALESCE(a.word_no = a1.word_no, TRUE) THEN
                            COALESCE(b1.word_no, 0)
                        ELSE
                            COALESCE(b2.word_no, b1.word_no, 0)
                    END,
                    CASE 
                        WHEN COALESCE(a.line_no = a1.line_no, TRUE) THEN
                            COALESCE(b1.line_no, 0)
                        ELSE
                            COALESCE(b2.line_no, b1.line_no, 0)
                    END
                FROM
                    %2$I.corpus a
                    LEFT JOIN %2$I.corpus a1 ON a.transliteration_id = a1.transliteration_id AND a1.sign_no = %1$s-2
                    LEFT JOIN %3$I.corpus b1 ON a.transliteration_id = b1.transliteration_id AND b1.sign_no = %1$s-2
                    LEFT JOIN %3$I.corpus b2 ON a.transliteration_id = b2.transliteration_id AND b2.sign_no = %1$s-1
                WHERE
                    a.transliteration_id = %4$s AND a.sign_no = %1$s-1
                $$,
                (op).pos,
                v_source_schema,
                v_target_schema,
                v_transliteration_id)
            INTO
                v_word_no,
                v_line_no;

            EXECUTE format(
                $$
                SELECT 
                    a.transliteration_id,
                    %1$s-1,
                    %5$s,
                    %6$s,
                    a.value_id,
                    a.sign_variant_id,
                    a.custom_value,
                    a.type,
                    a.indicator_type,
                    a.phonographic,
                    a.stem,
                    a.condition,
                    a.crits,
                    a.comment,
                    a.newline,
                    a.inverted,
                    a.ligature
                FROM 
                    %2$I.corpus a
                    LEFT JOIN %3$I.corpus b ON a.transliteration_id = b.transliteration_id AND b.sign_no = %1$s-2
                WHERE
                    a.transliteration_id = %4$s AND a.sign_no = %1$s-1
                $$,
                (op).pos,
                v_source_schema,
                v_target_schema,
                v_transliteration_id,
                v_line_no,
                v_word_no)
                INTO rec;

            RETURN QUERY SELECT * FROM insert_entry(v_transliteration_id, (op).pos-1, 'corpus', 'sign_no', rec, v_target_schema);
        ELSIF (op).op = 'DELETE' THEN
            RETURN QUERY SELECT * FROM delete_entry(v_transliteration_id, (op).pos-1, 'corpus', 'sign_no', v_target_schema);
        END IF;
    END LOOP;

    FOREACH col IN ARRAY array['custom_value', 'value_id', 'sign_variant_id', 'type', 'indicator_type', 'phonographic', 'stem', 
                               'condition', 'crits', 'comment', 'newline', 'inverted', 'ligature'] LOOP
        RETURN QUERY SELECT * FROM update_all_entries(v_transliteration_id, 'corpus', 'sign_no', col, v_source_schema, v_target_schema);
    END LOOP;

    RETURN QUERY SELECT * FROM delete_empty_entries(v_transliteration_id, 'words', 'corpus', 'word_no', v_target_schema);
    RETURN QUERY SELECT * FROM split_merge_all_entries(v_transliteration_id, 'words', 'corpus', 'word_no', 'sign_no', word_columns, word_special_col, v_source_schema, v_target_schema);
    RETURN QUERY SELECT * FROM update_all_entries(v_transliteration_id, 'words', 'word_no', word_columns, word_special_col, v_source_schema, v_target_schema);   

    RETURN QUERY SELECT * FROM delete_empty_entries(v_transliteration_id, 'compounds', 'words', 'compound_no', v_target_schema);
    RETURN QUERY SELECT * FROM split_merge_all_entries(v_transliteration_id, 'compounds', 'words', 'compound_no', 'word_no', compound_columns, compound_special_col, v_source_schema, v_target_schema);
    RETURN QUERY SELECT * FROM align_sections(v_transliteration_id, v_source_schema, v_target_schema);
    RETURN QUERY SELECT * FROM delete_empty_entries(v_transliteration_id, 'sections', 'compounds', 'section_no', v_target_schema);
    RETURN QUERY SELECT * FROM update_all_entries(v_transliteration_id, 'compounds', 'compound_no', compound_columns, compound_special_col, v_source_schema, v_target_schema);
    RETURN QUERY SELECT * FROM update_all_entries(v_transliteration_id, 'sections', 'section_no', section_columns, section_special_col, v_source_schema, v_target_schema);

    RETURN QUERY SELECT * FROM delete_empty_entries(v_transliteration_id, 'lines', 'corpus', 'line_no', v_target_schema);
    RETURN QUERY SELECT * FROM split_merge_all_entries(v_transliteration_id, 'lines', 'corpus', 'line_no', 'sign_no', line_columns, line_special_col, v_source_schema, v_target_schema);
    RETURN QUERY SELECT * FROM update_all_entries(v_transliteration_id, 'lines', 'line_no', line_columns, line_special_col, v_source_schema, v_target_schema);

    RETURN QUERY SELECT * FROM delete_empty_entries(v_transliteration_id, 'blocks', 'lines', 'block_no', v_target_schema);
    RETURN QUERY SELECT * FROM split_merge_all_entries(v_transliteration_id, 'blocks', 'lines', 'block_no', 'line_no', block_columns, block_special_col, v_source_schema, v_target_schema);
    RETURN QUERY SELECT * FROM update_all_entries(v_transliteration_id, 'blocks', 'block_no', block_columns, block_special_col, v_source_schema, v_target_schema);

    RETURN QUERY SELECT * FROM delete_empty_entries(v_transliteration_id, 'surfaces', 'blocks', 'surface_no', v_target_schema);
    RETURN QUERY SELECT * FROM split_merge_all_entries(v_transliteration_id, 'surfaces', 'blocks', 'surface_no', 'block_no', surface_columns, surface_special_col, v_source_schema, v_target_schema);
    RETURN QUERY SELECT * FROM update_all_entries(v_transliteration_id, 'surfaces', 'surface_no', surface_columns, surface_special_col, v_source_schema, v_target_schema);

    RETURN;
END;

$BODY$;