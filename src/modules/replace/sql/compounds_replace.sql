CREATE OR REPLACE FUNCTION compounds_replace (
        v_transliteration_id integer,
        v_corpus_table text,
        v_corpus_schema text,
        v_source_schema text
    )
    RETURNS SETOF compounds_type
    STABLE
    ROWS 100
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
RETURN QUERY EXECUTE format($$
    WITH x AS (
        SELECT
            transliteration_id,
            pattern_id,
            (row_number() OVER (PARTITION BY transliteration_id ORDER BY sign_no) - 1)::integer AS compound_no,
            pattern_compound,
            compound_no_ref
        FROM
            %1$I.%2$I
        WHERE
            compound_no_ref IS NOT NULL   
            AND transliteration_id = %3$s
    )
    SELECT
        x.transliteration_id,
        x.compound_no,
        COALESCE(a.pn_type, b.pn_type) AS pn_type,
        COALESCE(a.language, b.language) AS language,
        a.section_no,
        a.compound_comment
    FROM
        x
        LEFT JOIN %4$I.compounds a ON (NOT pattern_compound AND x.transliteration_id = a.transliteration_id AND x.compound_no_ref = a.compound_no)
        LEFT JOIN replace_pattern_compounds b ON (pattern_compound AND x.pattern_id = b.pattern_id AND x.compound_no_ref = b.compound_no);
    $$,
    v_corpus_schema,
    v_corpus_table,
    v_transliteration_id,
    v_source_schema);
RETURN;
END;
$BODY$;