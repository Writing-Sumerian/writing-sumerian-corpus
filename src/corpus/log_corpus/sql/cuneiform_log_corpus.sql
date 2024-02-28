CREATE OR REPLACE VIEW corpus_modified AS
WITH corpus_edits AS (
    SELECT
        row_number() OVER (PARTITION BY transliteration_id ORDER BY edit_id DESC, log_no DESC) AS ord,
        transliteration_id,
        sign_no,
        edit_id::integer,
        entry_no,
        split_part(action, ' ', 1) AS action,
        val
    FROM 
        edit_log 
        JOIN edits USING (edit_id)
        JOIN corpus USING (transliteration_id)
    WHERE
        target = 'corpus'
    UNION ALL
    SELECT
        0,
        transliteration_id,
        sign_no,
        NULL,
        sign_no,
        NULL,
        NULL
    FROM corpus
)
SELECT
    transliteration_id,
    sign_no,
    log_agg(edit_id, action, entry_no, val ORDER BY ord) AS edit_ids
FROM
    corpus_edits
GROUP BY
    transliteration_id,
    sign_no;


CREATE OR REPLACE PROCEDURE revert_corpus_to (
    v_transliteration_id integer, 
    v_timestamp timestamp
    )
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
    CALL revert_to(v_transliteration_id, v_timestamp, 'public');
    DELETE FROM edits WHERE transliteration_id = v_transliteration_id AND timestamp > v_timestamp;
END;
$BODY$;