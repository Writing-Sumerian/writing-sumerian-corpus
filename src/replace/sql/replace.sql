CREATE OR REPLACE PROCEDURE replace (
    search_term text, 
    pattern text,
    language language,
    stemmed boolean,
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
    v_reference_ids integer[];
    v_reference_sign_nos integer[];
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

    FOR v_transliteration_id, v_sign_nos, v_reference_ids, v_reference_sign_nos IN 
        SELECT 
            a.transliteration_id, 
            a.sign_nos, 
            array_agg(reference_id ORDER BY reference_id, ord) FILTER (WHERE reference_id IS NOT NULL), 
            array_agg(c.sign_no ORDER BY reference_id, ord) FILTER (WHERE reference_id IS NOT NULL)
        FROM    
            (SELECT row_number() OVER (), * FROM search(v_search_term_norm, period_ids, provenience_ids, genre_ids)) a
            LEFT JOIN LATERAL unnest(wildcards) AS b ON TRUE
            LEFT JOIN LATERAL unnest(b.sign_nos) WITH ORDINALITY AS c(sign_no, ord) ON TRUE
            LEFT JOIN LATERAL unnest(v_wildcards_explicit) WITH ORDINALITY AS _(wildcard_id, reference_id) USING (wildcard_id)
       GROUP BY
            row_number,
            a.transliteration_id, 
            a.sign_nos
    LOOP
        BEGIN
            INSERT INTO replace.corpus SELECT * FROM corpus_replace(v_transliteration_id, v_pattern_id, v_sign_nos, v_reference_ids, v_reference_sign_nos);
            
            SELECT array_agg(sign_no) INTO v_invalid_sign_nos FROM replace.corpus WHERE transliteration_id = v_transliteration_id AND NOT valid;
            SELECT array_agg(compound_no) INTO  v_invalid_compound_nos 
            FROM (
                SELECT compound_no FROM compounds WHERE transliteration_id = v_transliteration_id AND compound_comment IS NOT NULL
                EXCEPT SELECT compound_no_ref FROM replace.corpus WHERE transliteration_id = v_transliteration_id AND NOT pattern_compound
            )_;
                
            IF v_invalid_sign_nos IS NOT NULL THEN
                RAISE NOTICE 'Skipping %s: Invalid replacement near %s', v_transliteration_id, v_invalid_sign_nos;
            ELSIF v_invalid_compound_nos IS NOT NULL THEN
                RAISE NOTICE 'Skipping %s: Cannot remove compounds %s', v_transliteration_id, v_invalid_compound_nos;
            ELSE
                RAISE NOTICE 'Replacing signs %s in %s', v_sign_nos, v_transliteration_id;
                CALL edit('replace', v_transliteration_id);
            END IF;
            DELETE FROM replace.corpus WHERE transliteration_id = v_transliteration_id;
        EXCEPTION
            WHEN not_null_violation THEN RAISE NOTICE 'Skipping %s: Signs missing in replacement', v_transliteration_id;
        END;
    END LOOP;
END;
$BODY$;