CREATE TABLE corpus_parsed_unencoded (
    transliteration_id integer,
    sign_no integer,
    value text,
    sign_spec text,
    type sign_type NOT NULL,
    line_no_code integer,
    start_col_code integer,
    stop_col_code integer,
    PRIMARY KEY (transliteration_id, sign_no)
);

CALL create_corpus_encoder('parser_corpus_encoder', 'corpus_parsed_unencoded', '{transliteration_id}');

CREATE OR REPLACE PROCEDURE parse (
    code text, 
    schema text,
    language LANGUAGE,
    stemmed boolean,
    id integer
    )
    LANGUAGE 'plpython3u'
    AS $BODY$

from cuneiformparser import parseText
import pandas as pd

corpus_plan = plpy.prepare(
    f"INSERT INTO {schema}.corpus VALUES ($1, $2, $3, $4, NULL, NULL, CASE WHEN $6 = 'value' OR $6 = 'sign' THEN NULL ELSE $5 END, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)", 
    ['integer', 'integer', 'integer', 'integer', 'text', 'sign_type', 'indicator_type', 'boolean', 'boolean', 'sign_condition', 'text', 'text', 'boolean', 'boolean', 'boolean']
)

corpus_unencoded_plan = plpy.prepare(
    f'INSERT INTO corpus_parsed_unencoded VALUES ($1, $2, $3, $4, $5, $6, $7, $8)', 
    ['integer', 'integer', 'text', 'text', 'sign_type', 'integer', 'integer', 'integer']
)

words_plan = plpy.prepare(
    f'INSERT INTO {schema}.words VALUES ($1, $2, $3, $4)',
    ['integer', 'integer', 'integer', 'boolean']
)

compounds_plan = plpy.prepare(
    f'INSERT INTO {schema}.compounds VALUES ($1, $2, $3, $4, $5, $6)',
    ['integer', 'integer', 'pn_type', 'language', 'integer', 'text']
)

sections_plan = plpy.prepare(
    f'INSERT INTO {schema}.sections SELECT $1, $2, $3, composition_id, $5 FROM compositions WHERE composition_name = $4',
    ['integer', 'integer', 'text', 'text', 'witness_type']
)

objects_plan = plpy.prepare(
    f'INSERT INTO {schema}.objects VALUES ($1, $2, $3, $4, $5)',
    ['integer', 'integer', 'object_type', 'text', 'text']
)

surfaces_plan = plpy.prepare(
    f'INSERT INTO {schema}.surfaces (transliteration_id, surface_no, object_no, surface_type, surface_data, surface_comment) VALUES ($1, $2, $3, $4, $5, $6)',
    ['integer', 'integer', 'integer', 'surface_type', 'text', 'text']
)

blocks_plan = plpy.prepare(
    f'INSERT INTO {schema}.blocks (transliteration_id, block_no, surface_no, block_type, block_data, block_comment) VALUES ($1, $2, $3, $4, $5, $6)',
    ['integer', 'integer', 'integer', 'block_type', 'text', 'text']
)

lines_plan = plpy.prepare(
    f'INSERT INTO {schema}.lines VALUES ($1, $2, $3, $4, $5)',
    ['integer', 'integer', 'integer', 'text', 'text']
)

errors_plan = plpy.prepare(
    f'INSERT INTO {schema}.errors VALUES ($1, $2, $3, $4, $5)',
    ['integer', 'integer', 'integer', 'text', 'text']
)

objects, surfaces, blocks, lines, signs, compounds, words, sections, errors = parseText(code, language, stemmed)

plpy.execute(f"DELETE FROM corpus_parsed_unencoded WHERE transliteration_id = {id}")

for ix, row in sections.iterrows():
    plpy.execute(sections_plan, [id, ix]+[row[key] for key in ['section_name', 'composition', 'witness_type']])
for ix, row in compounds.iterrows():
    plpy.execute(compounds_plan, [id, ix]+[row[key] if row[key] is not pd.NA else None for key in ['pn_type', 'language', 'section_no', 'comment']])
for ix, row in words.iterrows():
    plpy.execute(words_plan, [id, ix]+[row[key] for key in ['compound_no', 'capitalized']])

for ix, row in objects.iterrows():
    plpy.execute(objects_plan, [id, ix]+[row[key] for key in ['object', 'data', 'comment']])
for ix, row in surfaces.iterrows():
    plpy.execute(surfaces_plan, [id, ix]+[row[key] for key in ['object_no', 'surface', 'data', 'comment']])
for ix, row in blocks.iterrows():
    plpy.execute(blocks_plan, [id, ix]+[row[key] for key in ['surface_no', 'block', 'data', 'comment']])
for ix, row in lines.iterrows():
    plpy.execute(lines_plan, [id, ix]+[row[key] for key in ['block_no', 'line', 'comment']])

for ix, row in signs.iterrows():
    plpy.execute(corpus_plan, [id, ix]+[row[key] for key in ['line_no', 'word_no', 'value', 'type', 'indicator_type', 'phonographic', 'stem', 'condition', 'crits', 'comment', 'newline', 'inverted', 'ligature']])
for ix, row in signs.iterrows():
    if row['type'] in ['value', 'sign']:
        plpy.execute(corpus_unencoded_plan, [id, ix]+[row[key] for key in ['value', 'sign_spec', 'type', 'line_no_code', 'start_col_code', 'stop_col_code']])

for ix, row in errors.iterrows():
    plpy.execute(errors_plan, [id]+[row[key] for key in ['line_no', 'column', 'symbol', 'msg']])

plpy.execute(f"""
    UPDATE {schema}.corpus SET 
        value_id = a.value_id, 
        sign_variant_id = a.sign_variant_id 
    FROM 
        parser_corpus_encoder a 
    WHERE 
        corpus.transliteration_id = a.transliteration_id AND 
        corpus.transliteration_id = {id} AND
        corpus.sign_no = a.sign_no
    """)

plpy.execute(f"""
    DELETE FROM corpus_parsed_unencoded
    USING {schema}.corpus
    WHERE
        corpus.transliteration_id = corpus_parsed_unencoded.transliteration_id AND 
        corpus.transliteration_id = {id} AND
        corpus.sign_no = corpus_parsed_unencoded.sign_no AND
        sign_variant_id IS NOT NULL
    """)

plpy.execute(f"""
    UPDATE {schema}.corpus SET 
        custom_value = corpus_parsed_unencoded.value  || COALESCE('(' || corpus_parsed_unencoded.sign_spec || ')', '')
    FROM
        corpus_parsed_unencoded
    WHERE
        corpus.transliteration_id = corpus_parsed_unencoded.transliteration_id AND
        corpus.transliteration_id = {id} AND
        corpus.sign_no = corpus_parsed_unencoded.sign_no;
    """)

$BODY$;