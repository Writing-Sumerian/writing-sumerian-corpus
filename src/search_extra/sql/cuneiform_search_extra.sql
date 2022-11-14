CREATE MATERIALIZED VIEW corpus_search AS (
WITH x AS (
  SELECT
    corpus.*,
    object_no,
    row_number() OVER (PARTITION BY transliteration_id, object_no ORDER BY sign_no) AS sign_position
  FROM
    corpus
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
    LEFT JOIN objects USING (transliteration_id, object_no)
)
SELECT * FROM (
  SELECT 
    transliteration_id,
    object_no,
    sign_no,
    cun_position(
      sign_position,
      a.pos::integer - 1, 
      row_number() OVER (PARTITION BY transliteration_id, sign_no ORDER BY pos DESC) = 1
      ) AS position,
    word_no,
    line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    grapheme_id,
    glyph_id,
    (properties).type,
    (properties).indicator,
    (properties).alignment,
    (properties).phonographic
  FROM 
    x
    JOIN sign_variants USING (sign_variant_id)
    LEFT JOIN LATERAL unnest(grapheme_ids, glyph_ids) WITH ORDINALITY a(grapheme_id, glyph_id, pos) ON TRUE
  UNION ALL
  SELECT
    transliteration_id,
    object_no,
    sign_no,
    cun_position(
      sign_position,
      0, 
      TRUE) AS position,
    word_no,
    line_no,
    value_id,
    sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    (properties).type,
    (properties).indicator,
    (properties).alignment,
    (properties).phonographic
  FROM 
    x
  WHERE (properties).type != 'punctuation' 
    AND (properties).type != 'damage'
  UNION ALL
  SELECT                      -- pseudo first row
    transliteration_id,
    object_no,
    NULL AS sign_no,
    cun_position(0, 0, TRUE) AS position,
    -1 AS word_no,
    -1 AS line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    NULL AS type,
    NULL AS indicator,
    NULL AS alignment,
    NULL AS phonographic
  FROM 
    x
  GROUP BY 
    transliteration_id,
    object_no
  UNION ALL
  SELECT                      -- pseudo final row
    transliteration_id,
    object_no,
    NULL AS sign_no,
    cun_position(
      max(sign_position)+1,
      0,
      TRUE) AS position,
    max(word_no)+1 AS word_no,
    max(line_no)+1 AS line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    NULL AS type,
    NULL AS indicator,
    NULL AS alignment,
    NULL AS phonographic
  FROM 
    x
  GROUP BY 
    transliteration_id,
    object_no
  UNION ALL
  SELECT                      -- placeholder row
    transliteration_id,
    object_no,
    NULL AS sign_no,
    NULL AS position,
    NULL AS word_no,
    NULL AS line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    NULL AS type,
    NULL AS indicator,
    NULL AS alignment,
    NULL AS phonographic
  FROM 
    x
  GROUP BY 
    transliteration_id,
    object_no)
  a
ORDER BY transliteration_id, object_no, position);

CREATE INDEX ON corpus_search (transliteration_id);
CREATE INDEX ON corpus_search (value_id) WHERE value_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, value_id) WHERE value_id IS NOT NULL;
CREATE INDEX ON corpus_search (sign_variant_id) WHERE sign_variant_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, sign_variant_id) WHERE sign_variant_id IS NOT NULL;
CREATE INDEX ON corpus_search (grapheme_id) WHERE grapheme_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, grapheme_id) WHERE grapheme_id IS NOT NULL;
CREATE INDEX ON corpus_search (glyph_id) WHERE glyph_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, glyph_id) WHERE glyph_id IS NOT NULL;
--CREATE INDEX ON corpus_search (transliteration_id, position);
ALTER MATERIALIZED VIEW corpus_search ALTER COLUMN value_id SET STATISTICS 1000;
ALTER MATERIALIZED VIEW corpus_search ALTER COLUMN sign_variant_id SET STATISTICS 1000;
ALTER MATERIALIZED VIEW corpus_search ALTER COLUMN grapheme_id SET STATISTICS 1000;
ALTER MATERIALIZED VIEW corpus_search ALTER COLUMN glyph_id SET STATISTICS 1000;


CREATE MATERIALIZED VIEW values_present AS
SELECT 
  value_id,
  period_id,
  provenience_id,
  genre_id,
  count(*) AS count,
  sum(1.0/transliteration_count) AS weight
FROM corpus
  LEFT JOIN transliterations USING (transliteration_id)
  LEFT JOIN texts_norm USING (text_id)
  LEFT JOIN (SELECT text_id, count(*) AS transliteration_count FROM transliterations GROUP BY text_id) _ USING (text_id)
GROUP BY
  value_id,
  period_id,
  provenience_id,
  genre_id;
 
CREATE MATERIALIZED VIEW sign_variants_present AS
SELECT DISTINCT 
  sign_variant_id,
  period_id,
  provenience_id,
  genre_id,
  count(*) AS count,
  sum(1.0/transliteration_count) AS weight
FROM corpus
  LEFT JOIN transliterations USING (transliteration_id)
  LEFT JOIN texts_norm USING (text_id)
  LEFT JOIN (SELECT text_id, count(*) AS transliteration_count FROM transliterations GROUP BY text_id) _ USING (text_id)
GROUP BY
  sign_variant_id,
  period_id,
  provenience_id,
  genre_id;


CREATE TYPE search_result AS (
    transliteration_id integer,
    text_id integer,
    corpus_id integer,
    period_id integer,
    provenience_id integer,
    genre_id integer,
    sign_nos integer[],
    word_nos integer[],
    line_nos integer[],
    wildcards search_wildcard[]
);


CREATE OR REPLACE FUNCTION search (
    search_term text,
    period_ids integer[] DEFAULT ARRAY[]::integer[],
    provenience_ids integer[] DEFAULT ARRAY[]::integer[],
    genre_ids integer[] DEFAULT ARRAY[]::integer[]
  )
  RETURNS SETOF search_result
  LANGUAGE PLPGSQL
  COST 100 
  STABLE 
  ROWS 1000
  AS $BODY$
BEGIN
  RETURN QUERY EXECUTE 
    $$
    SELECT
        transliteration_id,
        text_id,
        corpus_id,
        period_id,
        provenience_id,
        genre_id,
        signs,
        words,
        lines,
        wildcards
    FROM ($$ || parse_search (search_term, 'corpus_search', ARRAY['transliteration_id', 'object_no']) || $$) _
        LEFT JOIN transliterations USING (transliteration_id)
        LEFT JOIN texts USING (text_id)
    WHERE 
        (cardinality($1) = 0 OR period_id = ANY($1)) AND
        (cardinality($2) = 0 OR provenience_id = ANY($2)) AND
        (cardinality($3) = 0 OR genre_id = ANY($3))
    $$
    USING period_ids, provenience_ids, genre_ids;
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
    (cun_agg(value, sign, variant_type, sign_no, word_no, compound_no, NULL, 0, properties, stem, 'intact', LANGUAGE, 
            FALSE, FALSE, FALSE, NULL, NULL, FALSE, NULL, NULL, NULL, FALSE ORDER BY sign_no))[1],
    signs
  FROM (
    SELECT
      row_number() OVER (),
      transliteration_id,
      signs,
      UNNEST(signs) AS sign_no
    FROM
      search (search_term)) a
  JOIN corpus_code_clean USING (transliteration_id, sign_no)
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
  corpus_code_clean.transliteration_id,
  (cun_agg (value, sign, variant_type, sign_no, corpus_code_clean.word_no, compound_no, NULL, 0, properties, stem, 'intact', LANGUAGE, 
            FALSE, FALSE, FALSE, NULL, NULL, FALSE, NULL, NULL, NULL, FALSE ORDER BY sign_no))[1]
FROM
  found_words
  JOIN corpus_code_clean ON found_words.transliteration_id = corpus_code_clean.transliteration_id
    AND word_no = ANY (word_nos)
GROUP BY
  corpus_code_clean.transliteration_id,
  row_number
ORDER BY
  corpus_code_clean.transliteration_id
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
  array_to_string(cun_agg(value, sign, variant_type, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, LANGUAGE, 
      inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no), '\n'),
  line_no
FROM
  found_lines
  JOIN corpus_code USING (transliteration_id, line_no)
GROUP BY
  row_number,
  transliteration_id,
  line_no
ORDER BY
  transliteration_id
$BODY$;