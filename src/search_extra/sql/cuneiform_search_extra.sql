CREATE MATERIALIZED VIEW corpus_search AS (
SELECT * FROM (
  SELECT 
    corpus_norm.transliteration_id,
    objects.object_no,
    corpus_norm.sign_no,
    cun_position(
      rank() OVER (PARTITION BY transliteration_id, object_no ORDER BY sign_no ASC),
      a.pos::integer - 1, 
      rank() OVER (PARTITION BY transliteration_id, sign_no ORDER BY pos DESC) = 1
      ) AS position,
    corpus_norm.word_no,
    corpus_norm.line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    grapheme_id,
    glyph_id,
    (corpus_norm.properties).type,
    (corpus_norm.properties).indicator,
    (corpus_norm.properties).alignment,
    (corpus_norm.properties).phonographic
  FROM corpus_norm
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
    LEFT JOIN objects USING (transliteration_id, object_no)
    JOIN sign_variants USING (sign_variant_id)
    LEFT JOIN LATERAL unnest(grapheme_ids, glyph_ids) WITH ORDINALITY a(grapheme_id, glyph_id, pos) ON TRUE
  UNION ALL
  SELECT
    corpus_norm.transliteration_id,
    objects.object_no,
    corpus_norm.sign_no,
    cun_position(
      rank() OVER (PARTITION BY transliteration_id, object_no ORDER BY sign_no ASC),
      0, 
      TRUE) AS position,
    corpus_norm.word_no,
    corpus_norm.line_no,
    corpus_norm.value_id,
    corpus_norm.sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    (corpus_norm.properties).type,
    (corpus_norm.properties).indicator,
    (corpus_norm.properties).alignment,
    (corpus_norm.properties).phonographic
  FROM corpus_norm
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
    LEFT JOIN objects USING (transliteration_id, object_no)
  WHERE (corpus_norm.properties).type != 'punctuation' 
    AND (corpus_norm.properties).type != 'damage'
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
  FROM corpus_norm
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
    LEFT JOIN objects USING (transliteration_id, object_no)
  GROUP BY 
    transliteration_id,
    object_no
  UNION ALL
  SELECT                      -- pseudo final row
    transliteration_id,
    object_no,
    NULL AS sign_no,
    cun_position(
      count(*)+1,
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
  FROM corpus_norm
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
    LEFT JOIN objects USING (transliteration_id, object_no)
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
  FROM corpus_norm
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
    LEFT JOIN objects USING (transliteration_id, object_no)
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
SELECT DISTINCT 
  value_id,
  period_id,
  provenience_id,
  genre_id
FROM corpus_norm
  JOIN transliterations USING (transliteration_id)
  JOIN texts_norm USING (text_id);
 
CREATE MATERIALIZED VIEW sign_variants_present AS
SELECT DISTINCT 
  sign_variant_id,
  period_id,
  provenience_id,
  genre_id
FROM corpus_norm
  JOIN transliterations USING (transliteration_id)
  JOIN texts_norm USING (text_id);

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
  RETURN QUERY EXECUTE 'WITH r AS MATERIALIZED (' || parse_search (search_term, 'corpus_search', ARRAY['transliteration_id', 'object_no']) || ')'
    'SELECT r.transliteration_id, r.signs FROM r JOIN transliterations USING (transliteration_id) JOIN texts_norm USING (text_id)'
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
    sign_variant_id INTEGER,
    variant_type sign_variant_type,
    properties sign_properties, 
    stem bool
);