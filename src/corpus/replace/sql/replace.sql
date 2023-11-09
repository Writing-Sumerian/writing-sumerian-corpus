CREATE OR REPLACE PROCEDURE replace (
    search_term text, 
    pattern text,
    language language,
    stemmed boolean,
    user_id integer,
    internal boolean,
    period_ids integer[] DEFAULT ARRAY[]::integer[],
    provenience_ids integer[] DEFAULT ARRAY[]::integer[],
    genre_ids integer[] DEFAULT ARRAY[]::integer[]
    )
    LANGUAGE PLPGSQL
AS $BODY$

DECLARE

    v_search_term_norm text;
    v_wildcards_explicit integer[];
    v_pattern_id integer;
    v_transliteration_id integer;
    v_sign_nos integer[];
    v_match_nos integer[];
    v_reference_ids integer[];
    v_reference_sign_nos integer[];
    v_reference_match_nos integer[];
    v_overlap boolean;
    v_invalid_sign_nos integer[];
    v_invalid_compound_nos integer[];

BEGIN

    CALL parse_replacement(pattern, language, stemmed, v_pattern_id);

    SELECT 
        preparse_search.code,
        preparse_search.wildcards_explicit
    INTO
        v_search_term_norm,
        v_wildcards_explicit
    FROM
        preparse_search(search_term);

    FOR v_transliteration_id, v_sign_nos, v_match_nos, v_reference_ids, v_reference_sign_nos, v_reference_match_nos, v_overlap IN 
        WITH 
        results AS (
            SELECT 
                row_number() OVER (PARTITION BY transliteration_id ORDER BY sign_nos[1]) AS match_no, 
                * 
            FROM 
                search(v_search_term_norm, period_ids, provenience_ids, genre_ids)
        ),
        sign_nos_ AS (
            SELECT
                transliteration_id,
                sign_no,
                match_no,
                count(*) OVER (PARTITION BY transliteration_id, sign_no) AS count
            FROM
                results
                LEFT JOIN LATERAL unnest(sign_nos) AS a(sign_no) ON TRUE
        ),
        sign_nos AS (
            SELECT
                transliteration_id,
                array_agg(sign_no) AS sign_nos,
                array_agg(match_no) AS match_nos,
                max(count) > 1 AS overlap
            FROM
                sign_nos_
            GROUP BY
                transliteration_id
        ),
        "references" AS (
            SELECT 
                transliteration_id, 
                array_agg(reference_id ORDER BY reference_id, ord) FILTER (WHERE reference_id IS NOT NULL) AS reference_ids, 
                array_agg(c.sign_no ORDER BY reference_id, ord) FILTER (WHERE reference_id IS NOT NULL) AS reference_sign_nos,
                array_agg(match_no ORDER BY reference_id, ord) FILTER (WHERE reference_id IS NOT NULL) AS reference_match_nos
            FROM    
                results
                LEFT JOIN LATERAL unnest(wildcards) AS b ON TRUE
                LEFT JOIN LATERAL unnest(b.sign_nos) WITH ORDINALITY AS c(sign_no, ord) ON TRUE
                LEFT JOIN LATERAL unnest(v_wildcards_explicit) WITH ORDINALITY AS _(wildcard_id, reference_id) USING (wildcard_id)
            GROUP BY
                transliteration_id
        )
        SELECT
            transliteration_id,
            sign_nos,
            match_nos,
            reference_ids,
            reference_sign_nos,
            reference_match_nos,
            overlap
        FROM
            sign_nos
            LEFT JOIN "references" USING (transliteration_id)
    LOOP
        IF v_overlap THEN
            RAISE NOTICE 'Skipping %, %: Overlapping match', v_transliteration_id, v_sign_nos;
            CONTINUE;
        END IF;
        BEGIN
            INSERT INTO replace.corpus SELECT * FROM corpus_replace(v_transliteration_id, v_pattern_id, v_sign_nos, v_match_nos, v_reference_ids, v_reference_sign_nos, v_reference_match_nos);
            INSERT INTO replace.words SELECT * FROM words_replace WHERE transliteration_id = v_transliteration_id;
            INSERT INTO replace.compounds SELECT * FROM compounds_replace WHERE transliteration_id = v_transliteration_id;
            
            SELECT array_agg(sign_no) INTO v_invalid_sign_nos FROM replace.corpus WHERE transliteration_id = v_transliteration_id AND NOT valid;
            SELECT array_agg(compound_no) INTO  v_invalid_compound_nos 
            FROM (
                SELECT compound_no FROM compounds WHERE transliteration_id = v_transliteration_id AND compound_comment IS NOT NULL
                EXCEPT SELECT compound_no_ref FROM replace.corpus WHERE transliteration_id = v_transliteration_id AND NOT pattern_compound
            )_;
                
            IF NOT v_invalid_sign_nos IS NULL THEN
                RAISE NOTICE 'Skipping %, %: Invalid replacement near %', v_transliteration_id, v_sign_nos, v_invalid_sign_nos;
            ELSIF NOT v_invalid_compound_nos IS NULL THEN
                RAISE NOTICE 'Skipping %, %: Cannot remove compounds %', v_transliteration_id, v_sign_nos, v_invalid_compound_nos;
            ELSE
                RAISE NOTICE 'Replacing signs % in %...', v_sign_nos, v_transliteration_id;
                CALL corpus_search_drop_triggers();
                CALL edit_corpus('replace', v_transliteration_id, user_id, internal);
                CALL corpus_search_create_triggers();
                CALL corpus_search_update_transliteration(v_transliteration_id);
                RAISE NOTICE 'Done.';
            END IF;

            DELETE FROM replace.corpus WHERE transliteration_id = v_transliteration_id;
            DELETE FROM replace.words WHERE transliteration_id = v_transliteration_id;
            DELETE FROM replace.compounds WHERE transliteration_id = v_transliteration_id;
        EXCEPTION
            WHEN not_null_violation THEN RAISE NOTICE 'Skipping %: Signs missing in replacement', v_transliteration_id;
        END;
    END LOOP;
END;
$BODY$;