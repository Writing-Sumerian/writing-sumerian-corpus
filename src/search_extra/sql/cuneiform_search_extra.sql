CREATE OR REPLACE FUNCTION public.search (
  search_term text, 
  periods integer[] DEFAULT ARRAY[]::integer[],
  proveniences integer[] DEFAULT ARRAY[]::integer[],
  genres integer[] DEFAULT ARRAY[]::integer[],  
  OUT transliteration_id integer, 
  OUT signs integer[]
  )
  RETURNS SETOF record
  LANGUAGE 'plpgsql'
  COST 100 STABLE ROWS 1000
  AS $BODY$
BEGIN
  RETURN QUERY EXECUTE 'WITH r AS MATERIALIZED (' || parse_search (search_term, 'corpus', 'corpus_composition', ARRAY['transliteration_id']) || ')'
    'SELECT r.* FROM r JOIN transliterations USING (transliteration_id) JOIN texts_norm USING (TEXT_ID)'
    'WHERE (cardinality($1) = 0 OR period_id = ANY($1)) AND'
          '(cardinality($2) = 0 OR provenience_id = ANY($2)) AND'
          '(cardinality($3) = 0 OR genre_id = ANY($3))'
    USING periods, proveniences, genres;
END;
$BODY$;


CREATE OR REPLACE FUNCTION public.search_signs_clean (search_term text)
  RETURNS TABLE (
    transliteration_id integer,
    signs text,
    sign_nos integer[])
  LANGUAGE 'sql'
  COST 100 STABLE ROWS 1000
  AS $BODY$
  SELECT
    transliteration_id,
    (cun_agg (COALESCE(value, sign, placeholder((properties).type)), value IS NULL, sign_no, word_no, compound_no, 0, properties, stem, 'intact',
      LANGUAGE, FALSE, FALSE, NULL, NULL, NULL, FALSE ORDER BY sign_no))[1],
    signs
  FROM (
    SELECT
      row_number() OVER (),
      transliteration_id,
      signs,
      UNNEST(signs) AS sign_no
    FROM
      search (search_term)) a
  JOIN corpus USING (transliteration_id, sign_no)
GROUP BY
  row_number,
  signs,
  transliteration_id
ORDER BY
  transliteration_id
$BODY$;


CREATE OR REPLACE FUNCTION public.search_words_clean (search_term text)
  RETURNS TABLE (
    transliteration_id integer,
    word text)
  LANGUAGE 'sql'
  COST 100 STABLE ROWS 1000
  AS $BODY$
  WITH res AS (
    SELECT DISTINCT
      row_number,
      transliteration_id,
      word_no
    FROM (
      SELECT
        row_number() OVER (),
        transliteration_id,
        UNNEST(signs) AS sign_no
    FROM
      search (search_term)) a
    JOIN corpus USING (transliteration_id, sign_no)
),
found_words AS (
  SELECT
    row_number,
    transliteration_id,
    array_agg(word_no) AS word_nos
  FROM
    res
  GROUP BY
    transliteration_id,
    row_number
)
SELECT
  corpus.transliteration_id,
  (cun_agg (COALESCE(value, sign, placeholder((properties).type)), value IS NULL, sign_no, corpus.word_no, compound_no, 0, properties, stem, 'intact',
    LANGUAGE, FALSE, FALSE, '', NULL, NULL, FALSE ORDER BY sign_no))[1]
FROM
  found_words
  JOIN corpus ON found_words.transliteration_id = corpus.transliteration_id
    AND word_no = ANY (word_nos)
GROUP BY
  corpus.transliteration_id,
  row_number
ORDER BY
  corpus.transliteration_id
$BODY$;

CREATE OR REPLACE FUNCTION public.search_lines (search_term text)
  RETURNS TABLE (
    transliteration_id integer,
    line text,
    line_no integer)
  LANGUAGE 'sql'
  COST 100 STABLE ROWS 1000
  AS $BODY$
  WITH found_lines AS (
    SELECT DISTINCT
      row_number,
      transliteration_id,
      line_no
    FROM (
      SELECT
        row_number() OVER (),
        transliteration_id,
        UNNEST(signs) AS sign_no
    FROM
      search (search_term)) a
    JOIN corpus USING (transliteration_id, sign_no))
SELECT
  transliteration_id,
  array_to_string( cun_agg (COALESCE(value, sign, orig_value), value IS NULL, sign_no, word_no, compound_no, line_no, properties, stem, condition,
    LANGUAGE, inverted, newline, crits, comment, compound_comment, FALSE ORDER BY sign_no), '\n'),
  line_no
FROM
  found_lines
  JOIN corpus USING (transliteration_id, line_no)
GROUP BY
  row_number,
  transliteration_id,
  line_no
ORDER BY
  transliteration_id
$BODY$;

CREATE OR REPLACE FUNCTION public.search_lines_html (search_term text)
  RETURNS TABLE (
    transliteration_id integer,
    line text,
    line_no integer)
  LANGUAGE 'sql'
  COST 100 STABLE ROWS 1000
  AS $BODY$
  WITH found_lines AS (
    SELECT DISTINCT
      row_number,
      transliteration_id,
      line_no
    FROM (
      SELECT
        row_number() OVER (),
        transliteration_id,
        UNNEST(signs) AS sign_no
    FROM
      search (search_term)) a
    JOIN corpus USING (transliteration_id, sign_no))
SELECT
  transliteration_id,
  array_to_string( cun_agg_html (COALESCE(mark_index_html(value), mark_index_html(sign), orig_value), value IS NULL, sign_no, word_no, compound_no, line_no, properties, stem, condition,
    LANGUAGE, inverted, newline, crits, comment, compound_comment, FALSE ORDER BY sign_no), '<br/>'),
  line_no
FROM
  found_lines
  JOIN corpus USING (transliteration_id, line_no)
GROUP BY
  row_number,
  transliteration_id,
  line_no
ORDER BY
  transliteration_id
$BODY$;

-- An array of these represents a match, only including destinctive informatition
CREATE TYPE sign_match AS (
    sign_no INTEGER, 
    word_no INTEGER, 
    compound_no INTEGER, 
    value_id INTEGER, 
    sign_id INTEGER, 
    properties sign_properties, 
    stem bool
);