CREATE TABLE corpus_search (
  transliteration_id integer NOT NULL,
  object_no integer NOT NULL,
  sign_no integer,
  position cun_position,
  word_no integer,
  compound_no integer,
  line_no integer,
  value_id integer,
  sign_variant_id integer,
  grapheme_id integer,
  glyph_id integer,
  type sign_type,
  indicator_type indicator_type,
  phonographic boolean
);

CREATE INDEX ON corpus_search (transliteration_id, object_no);
CREATE INDEX ON corpus_search (value_id) WHERE value_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, object_no, value_id) WHERE value_id IS NOT NULL;
CREATE INDEX ON corpus_search (sign_variant_id) WHERE sign_variant_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, object_no, sign_variant_id) WHERE sign_variant_id IS NOT NULL;
CREATE INDEX ON corpus_search (grapheme_id) WHERE grapheme_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, object_no, grapheme_id) WHERE grapheme_id IS NOT NULL;
CREATE INDEX ON corpus_search (glyph_id) WHERE glyph_id IS NOT NULL;
CREATE INDEX ON corpus_search (transliteration_id, object_no, glyph_id) WHERE glyph_id IS NOT NULL;
CREATE INDEX corpus_search_transliteration_id_object_no_position_ix ON corpus_search (transliteration_id, object_no, position);
CLUSTER corpus_search USING corpus_search_transliteration_id_object_no_position_ix;

ALTER TABLE corpus_search ALTER COLUMN value_id SET STATISTICS 1000;
ALTER TABLE corpus_search ALTER COLUMN sign_variant_id SET STATISTICS 1000;
ALTER TABLE corpus_search ALTER COLUMN grapheme_id SET STATISTICS 1000;
ALTER TABLE corpus_search ALTER COLUMN glyph_id SET STATISTICS 1000;


CREATE OR REPLACE FUNCTION corpus_search_update_marginals (
    v_transliteration_id integer,
    v_object_no integer
  )
  RETURNS void
  VOLATILE
  LANGUAGE SQL
  AS
$BODY$
  DELETE FROM corpus_search
  WHERE
    transliteration_id = v_transliteration_id
    AND object_no = v_object_no
    AND sign_no IS NULL;

  INSERT INTO corpus_search 
  SELECT
    *
  FROM 
    corpus_search_view
  WHERE
    transliteration_id = v_transliteration_id
    AND object_no = v_object_no
    AND sign_no IS NULL;
$BODY$;


CREATE FUNCTION corpus_search_corpus_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
DECLARE

v_object_no integer;

BEGIN

  DELETE FROM corpus_search
  WHERE
    transliteration_id = (OLD).transliteration_id
    AND sign_no = (OLD).sign_no;

  IF NOT NEW IS NULL THEN
    INSERT INTO corpus_search 
    SELECT
      *
    FROM
      corpus_search_view
    WHERE
      transliteration_id = (NEW).transliteration_id
      AND sign_no = (NEW).sign_no;
  END IF;

  PERFORM 
    corpus_search_update_marginals(transliteration_id, object_no) 
  FROM
    lines
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
  WHERE
    transliteration_id = COALESCE((OLD).transliteration_id, (NEW).transliteration_id)
    AND (line_no = (OLD).line_no OR line_no = (NEW).line_no);

  RETURN NULL;

END;
$BODY$;

CREATE FUNCTION corpus_search_update_lines_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
DECLARE
  v_object_no_new integer;
  v_object_no_old integer;
BEGIN
  SELECT 
    object_no
  INTO
    v_object_no_old
  FROM
    blocks
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
  WHERE
    transliteration_id = (OLD).transliteration_id
    AND block_no = (OLD).block_no;

  SELECT 
    object_no
  INTO
    v_object_no_new
  FROM
    blocks
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
  WHERE
    transliteration_id = (NEW).transliteration_id
    AND block_no = (NEW).block_no;

  IF v_object_no_old != v_object_no_new THEN

    UPDATE corpus_search SET
      object_no = v_object_no_new
    FROM
      corpus
    WHERE
      corpus.transliteration_id = (OLD).transliteration_id
      AND corpus.line_no = (OLD).line_no
      AND corpus.transliteration_id = corpus_search.transliteration_id
      AND corpus.sign_no = corpus_search.sign_no;

    PERFORM corpus_search_update_marginals((OLD).transliteration_id, v_object_no_old);
    PERFORM corpus_search_update_marginals((NEW).transliteration_id, v_object_no_new);

  END IF;
  
  RETURN NULL;

END;
$BODY$;

CREATE FUNCTION corpus_search_update_blocks_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
DECLARE
  v_object_no_new integer;
  v_object_no_old integer;
BEGIN
  SELECT 
    object_no
  INTO
    v_object_no_old
  FROM
    surfaces
  WHERE
    transliteration_id = (OLD).transliteration_id
    AND surface_no = (OLD).surface_no;

  SELECT 
    object_no
  INTO
    v_object_no_new
  FROM
    surfaces
  WHERE
    transliteration_id = (NEW).transliteration_id
    AND surface_no = (NEW).surface_no;

  IF v_object_no_old != v_object_no_new THEN

    UPDATE corpus_search SET
      object_no = v_object_no_new
    FROM
      corpus
      LEFT JOIN lines USING (transliteration_id, line_no)
    WHERE
      corpus.transliteration_id = (OLD).transliteration_id
      AND lines.block_no = (OLD).block_no
      AND corpus.transliteration_id = corpus_search.transliteration_id
      AND corpus.sign_no = corpus_search.sign_no;

    PERFORM corpus_search_update_marginals((OLD).transliteration_id, v_object_no_old);
    PERFORM corpus_search_update_marginals((NEW).transliteration_id, v_object_no_new);

  END IF;

  RETURN NULL;
  
END;
$BODY$;


CREATE FUNCTION corpus_search_update_surfaces_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN

  IF (OLD).object_no != (NEW).object_no THEN

    UPDATE corpus_search SET
      object_no = (NEW).object_no
    FROM
      corpus
      LEFT JOIN lines USING (transliteration_id, line_no)
      LEFT JOIN blocks USING (transliteration_id, block_no)
    WHERE
      corpus.transliteration_id = (OLD).transliteration_id
      AND blocks.surface_no = (OLD).surface_no
      AND corpus.transliteration_id = corpus_search.transliteration_id
      AND corpus.sign_no = corpus_search.sign_no;

    PERFORM corpus_search_update_marginals((OLD).transliteration_id, (OLD).object_no);
    PERFORM corpus_search_update_marginals((NEW).transliteration_id, (NEW).object_no);

  END IF;

  RETURN NULL;
  
END;
$BODY$;

CREATE OR REPLACE FUNCTION corpus_search_update_words_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN

  IF (OLD).compound_no != (NEW).compound_no THEN

    UPDATE corpus_search SET
      compound_no = (NEW).compound_no
    FROM
      corpus
      LEFT JOIN words USING (transliteration_id, word_no)
    WHERE
      corpus.transliteration_id = (OLD).transliteration_id
      AND words.word_no = (OLD).word_no
      AND corpus.transliteration_id = corpus_search.transliteration_id
      AND corpus.sign_no = corpus_search.sign_no;

    PERFORM 
      corpus_search_update_marginals((OLD).transliteration_id, min(object_no))
    FROM
      corpus
      LEFT JOIN lines USING (transliteration_id, line_no)
      LEFT JOIN blocks USING (transliteration_id, block_no)
      LEFT JOIN surfaces USING (transliteration_id, surface_no)
    WHERE
      transliteration_id = (OLD).transliteration_id
      AND word_no = (OLD).word_no;

  END IF;

  RETURN NULL;
  
END;
$BODY$;


CREATE OR REPLACE FUNCTION corpus_search_update_sign_variants_composition_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN

  IF (OLD).graphemes = (NEW).graphemes AND (OLD).glyphs = (NEW).glyphs THEN
    RETURN NULL;
  END IF;

  DELETE FROM corpus_search USING corpus 
  WHERE 
    corpus.transliteration_id = corpus_search.transliteration_id
    AND corpus.sign_no = corpus_search.sign_no
    AND corpus.sign_variant_id = (OLD).sign_variant_id
    AND corpus_search.sign_variant_id IS NULL;
  
  INSERT INTO corpus_search 
  SELECT corpus_search_view.*
  FROM 
    corpus
    JOIN corpus_search_view USING (transliteration_id, sign_no)
  WHERE
    corpus.sign_variant_id = (OLD).sign_variant_id
    AND corpus_search_view.sign_variant_id IS NULL;
  
  RETURN NULL;

END;
$BODY$;


CREATE OR REPLACE PROCEDURE corpus_search_create_triggers()
  LANGUAGE SQL
  AS
$BODY$
  CREATE TRIGGER corpus_search_corpus_trigger
    AFTER DELETE OR INSERT OR UPDATE OF transliteration_id, value_id, sign_variant_id, type, indicator_type, phonographic ON corpus 
    FOR EACH ROW
    EXECUTE FUNCTION corpus_search_corpus_trigger_fun();

  CREATE TRIGGER corpus_search_corpus_index_col_trigger
    AFTER UPDATE OF sign_no, word_no, line_no ON corpus 
    FOR EACH ROW
    WHEN (NEW.sign_no >= 0 AND NEW.line_no >= 0 AND NEW.word_no >= 0)
    EXECUTE FUNCTION corpus_search_corpus_trigger_fun();

  CREATE TRIGGER corpus_search_update_lines_trigger
    AFTER UPDATE OF block_no ON lines
    FOR EACH ROW
    WHEN (NEW.block_no != OLD.block_no AND NEW.block_no >= 0)
    EXECUTE FUNCTION corpus_search_update_lines_trigger_fun();

  CREATE TRIGGER corpus_search_update_blocks_trigger
    AFTER UPDATE OF surface_no ON blocks
    FOR EACH ROW
    WHEN (NEW.surface_no != OLD.surface_no AND NEW.surface_no >= 0)
    EXECUTE FUNCTION corpus_search_update_blocks_trigger_fun();

  CREATE TRIGGER corpus_search_update_surfaces_trigger
    AFTER UPDATE OF object_no ON surfaces
    FOR EACH ROW
    WHEN (NEW.object_no != OLD.object_no AND NEW.object_no >= 0)
    EXECUTE FUNCTION corpus_search_update_surfaces_trigger_fun();

  CREATE TRIGGER corpus_search_update_words_trigger
    AFTER UPDATE OF compound_no ON words
    FOR EACH ROW
    WHEN (NEW.compound_no != OLD.compound_no AND NEW.compound_no >= 0)
    EXECUTE FUNCTION corpus_search_update_words_trigger_fun();

  CREATE TRIGGER corpus_search_update_sign_variants_composition_trigger
    AFTER UPDATE OF grapheme_ids, glyph_ids ON sign_variants_composition
    FOR EACH ROW
    EXECUTE FUNCTION corpus_search_update_sign_variants_composition_trigger_fun();
$BODY$;

CREATE OR REPLACE PROCEDURE corpus_search_drop_triggers()
  LANGUAGE SQL
  AS
$BODY$
  DROP TRIGGER corpus_search_corpus_trigger ON corpus;
  DROP TRIGGER corpus_search_corpus_index_col_trigger ON corpus;
  DROP TRIGGER corpus_search_update_lines_trigger ON lines;
  DROP TRIGGER corpus_search_update_blocks_trigger ON blocks;
  DROP TRIGGER corpus_search_update_surfaces_trigger ON surfaces;
  DROP TRIGGER corpus_search_update_words_trigger ON words;
  DROP TRIGGER corpus_search_update_sign_variants_composition_trigger ON sign_variants_composition;
$BODY$;


CREATE OR REPLACE VIEW corpus_search_view AS (
WITH x AS NOT MATERIALIZED (
  SELECT
    corpus.*,
    compound_no,
    object_no
  FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no)
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN blocks USING (transliteration_id, block_no)
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
)
SELECT * FROM (
  SELECT 
    transliteration_id,
    object_no,
    sign_no,
    cun_position(
      greatest(sign_no + 1, 0),
      a.pos::integer - 1, 
      row_number() OVER (PARTITION BY transliteration_id, sign_no ORDER BY pos DESC) = 1
      ) AS position,
    word_no,
    compound_no,
    line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    grapheme_id,
    glyph_id,
    type,
    indicator_type,
    phonographic
  FROM 
    x
    JOIN sign_variants_composition USING (sign_variant_id)
    LEFT JOIN LATERAL unnest(grapheme_ids, glyph_ids) WITH ORDINALITY a(grapheme_id, glyph_id, pos) ON TRUE
  UNION ALL
  SELECT
    transliteration_id,
    object_no,
    sign_no,
    cun_position(
      greatest(sign_no + 1, 0),
      0, 
      TRUE) AS position,
    word_no,
    compound_no,
    line_no,
    value_id,
    sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    type,
    indicator_type,
    phonographic
  FROM 
    x
  UNION ALL
  SELECT                      -- pseudo first row
    transliteration_id,
    object_no,
    NULL AS sign_no,
    cun_position(greatest(min(sign_no), 0), 0, TRUE) AS position,
    min(word_no)-1 AS word_no,
    min(compound_no)-1 AS compound_no,
    min(line_no)-1 AS line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    NULL AS type,
    NULL AS indicator_type,
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
      greatest(max(sign_no)+2, 0),
      0,
      TRUE) AS position,
    max(word_no)+1 AS word_no,
    max(compound_no)+1 AS compound_no,
    max(line_no)+1 AS line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    NULL AS type,
    NULL AS indicator_type,
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
    NULL AS compound_no,
    NULL AS line_no,
    NULL AS value_id,
    NULL AS sign_variant_id,
    NULL AS grapheme_id,
    NULL AS glyph_id,
    NULL AS type,
    NULL AS indicator_type,
    NULL AS phonographic
  FROM 
    x
  GROUP BY 
    transliteration_id,
    object_no)
  a
ORDER BY transliteration_id, object_no, position);


CREATE PROCEDURE corpus_search_update_transliteration(v_transliteration_id integer)
  LANGUAGE SQL
  AS
$BODY$
  DELETE FROM corpus_search WHERE transliteration_id = v_transliteration_id;
  INSERT INTO corpus_search SELECT * FROM corpus_search_view WHERE transliteration_id = v_transliteration_id;
$BODY$;

CALL corpus_search_create_triggers();


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


CREATE OR REPLACE FUNCTION search_signs_clean (search_term text)
  RETURNS TABLE (
    transliteration_id integer,
    signs text,
    sign_nos integer[])
  LANGUAGE 'sql'
  COST 100 STABLE ROWS 1000
  AS $BODY$
  SELECT
    transliteration_id,
    (cun_agg(value, sign, variant_type, sign_no, word_no, compound_no, NULL, 0, type, indicator_type, phonographic, stem, 'intact', LANGUAGE, 
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


CREATE OR REPLACE FUNCTION search_words_clean (search_term text)
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
  (cun_agg (value, sign, variant_type, sign_no, corpus_code_clean.word_no, compound_no, NULL, 0, type, indicator_type, phonographic, stem, 'intact', LANGUAGE, 
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

CREATE OR REPLACE FUNCTION search_lines (search_term text)
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
  array_to_string(cun_agg(value, sign, variant_type, sign_no, word_no, compound_no, section_no, line_no, type, indicator_type, phonographic, stem, condition, LANGUAGE, 
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