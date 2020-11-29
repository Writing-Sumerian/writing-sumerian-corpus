CREATE OR REPLACE FUNCTION public.search(
    search_term text,
    OUT text_id integer,
    OUT signs integer[])
    RETURNS SETOF record 
    LANGUAGE 'plpgsql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$
BEGIN
    RETURN QUERY EXECUTE parse_search(search_term, 'corpus', ARRAY['text_id']);
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.search_signs(
	search_term text)
    RETURNS TABLE(text_id integer, signs text, sign_nos integer[]) 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$
SELECT 
    corpus.text_id,  
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no),
    signs
  FROM 
    (SELECT row_number() OVER (), text_id, signs, UNNEST(signs) AS sign_no FROM search(search_term)) a
    JOIN corpus USING (text_id, sign_no) 
    LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
    LEFT JOIN signs USING (sign_id)
    JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
  GROUP BY row_number, signs, corpus.text_id
  ORDER BY corpus.text_id
$BODY$;

CREATE OR REPLACE FUNCTION public.search_signs_html(
	search_term text)
    RETURNS TABLE(text_id integer, signs text, sign_nos integer[]) 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$
SELECT 
    corpus.text_id,  
    cun_agg_html (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no),
    signs
  FROM 
    (SELECT row_number() OVER (), text_id, signs, UNNEST(signs) AS sign_no FROM search(search_term)) a
    JOIN corpus USING (text_id, sign_no) 
    LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
    LEFT JOIN signs USING (sign_id)
    JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
  GROUP BY row_number, signs, corpus.text_id
  ORDER BY corpus.text_id
$BODY$;


CREATE OR REPLACE FUNCTION public.search_words(
	search_term text)
    RETURNS TABLE(text_id integer, word text, word_no integer) 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$
WITH found_words AS 
 (SELECT DISTINCT 
    row_number, 
    text_id,  
    word_no 
   FROM 
    (SELECT row_number() OVER (), text_id, UNNEST(signs) AS sign_no FROM search(search_term)) a 
    JOIN corpus USING (text_id, sign_no))
SELECT 
    corpus.text_id,
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no),
    corpus.word_no
  FROM found_words 
    JOIN corpus USING (text_id, word_no)
    LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
    LEFT JOIN signs USING (sign_id)
    JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
  GROUP BY row_number, corpus.text_id, corpus.word_no
  ORDER BY corpus.text_id
$BODY$;

CREATE OR REPLACE FUNCTION public.search_words_html(
	search_term text)
    RETURNS TABLE(text_id integer, word text, word_no integer) 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$
WITH found_words AS 
 (SELECT DISTINCT 
    row_number, 
    text_id,  
    word_no 
   FROM 
    (SELECT row_number() OVER (), text_id, UNNEST(signs) AS sign_no FROM search(search_term)) a 
    JOIN corpus USING (text_id, sign_no))
SELECT 
    corpus.text_id,
    cun_agg_html (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no),
    corpus.word_no
  FROM found_words 
    JOIN corpus USING (text_id, word_no)
    LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
    LEFT JOIN signs USING (sign_id)
    JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
  GROUP BY row_number, corpus.text_id, corpus.word_no
  ORDER BY corpus.text_id
$BODY$;

CREATE OR REPLACE FUNCTION public.search_lines(
	search_term text)
    RETURNS TABLE(text_id integer, line text, line_no integer) 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$
WITH found_lines AS 
 (SELECT DISTINCT 
    row_number, 
    text_id,  
    line_no 
   FROM 
    (SELECT row_number() OVER (), text_id, UNNEST(signs) AS sign_no FROM search(search_term)) a 
    JOIN corpus USING (text_id, sign_no))
SELECT 
    corpus.text_id,  
    cun_agg (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no),
    line_no
  FROM found_lines 
    JOIN corpus USING (text_id, line_no) 
    LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
    LEFT JOIN signs USING (sign_id)
    JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
  GROUP BY row_number, corpus.text_id, line_no
  ORDER BY corpus.text_id
$BODY$;

CREATE OR REPLACE FUNCTION public.search_lines_html(
	search_term text)
    RETURNS TABLE(text_id integer, line text, line_no integer) 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$
WITH found_lines AS 
 (SELECT DISTINCT 
    row_number, 
    text_id,  
    line_no 
   FROM 
    (SELECT row_number() OVER (), text_id, UNNEST(signs) AS sign_no FROM search(search_term)) a 
    JOIN corpus USING (text_id, sign_no))
SELECT 
    corpus.text_id,  
    cun_agg_html (COALESCE(value, signs.name, orig_value), value IS NULL, corpus.sign_no, corpus.word_no, compound_no, line_no, properties, stem, condition, language, inverted, newline, crits, corpus.comment ORDER BY corpus.sign_no),
    line_no
  FROM found_lines 
    JOIN corpus USING (text_id, line_no) 
    LEFT JOIN value_variants ON corpus.value_id = value_variants.value_id AND main
    LEFT JOIN signs USING (sign_id)
    JOIN words ON corpus.text_id = words.text_id AND corpus.word_no = words.word_no
  GROUP BY row_number, corpus.text_id, line_no
  ORDER BY corpus.text_id
$BODY$;