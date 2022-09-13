CREATE TABLE corpus_parsed_unencoded (
    transliteration_id integer,
    sign_no integer,
    value text,
    sign_spec text,
    type sign_type NOT NULL,
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
    f"INSERT INTO {schema}.corpus VALUES ($1, $2, $3, $4, $5 || COALESCE('(' || $6  || ')', ''), NULL, NULL, CASE WHEN $7 = 'number' THEN $5 ELSE NULL END, ($7, $8, $9, $10)::sign_properties, $11, $12, $13, $14, $15, $16, $17)", 
    ['integer', 'integer', 'integer', 'integer', 'text', 'text', 'sign_type', 'boolean', 'alignment', 'boolean', 'boolean', 'sign_condition', 'text', 'text', 'boolean', 'boolean', 'boolean']
)

corpus_unencoded_plan = plpy.prepare(
    f'INSERT INTO corpus_parsed_unencoded VALUES ($1, $2, $3, $4, $5)', 
    ['integer', 'integer', 'text', 'text', 'sign_type']
)

words_plan = plpy.prepare(
    f'INSERT INTO {schema}.words VALUES ($1, $2, $3, $4)',
    ['integer', 'integer', 'integer', 'boolean']
)

compounds_plan = plpy.prepare(
    f'INSERT INTO {schema}.compounds VALUES ($1, $2, $3, $4, $5)',
    ['integer', 'integer', 'pn_type', 'language', 'text']
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

objects, surfaces, blocks, lines, signs, compounds, words, errors = parseText(code, language, stemmed)

plpy.execute(f"DELETE FROM corpus_parsed_unencoded WHERE transliteration_id = {id}")

for ix, row in compounds.iterrows():
    plpy.execute(compounds_plan, [id, ix]+[row[key] for key in ['pn_type', 'language', 'comment']])
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
    plpy.execute(corpus_plan, [id, ix]+[row[key] for key in ['line_no', 'word_no', 'value', 'sign_spec', 'type', 'indicator', 'alignment', 'phonographic', 'stem', 'condition', 'crits', 'comment', 'newline', 'inverted', 'ligature']])
for ix, row in signs.iterrows():
    if row['type'] in ['value', 'sign'] or (row['type'] == 'number' and row['sign_spec'] is not None):
        plpy.execute(corpus_unencoded_plan, [id, ix]+[row[key] for key in ['value', 'sign_spec', 'type']])

for ix, row in errors.iterrows():
    plpy.execute(errors_plan, [id]+[row[key] for key in ['line', 'column', 'symbol', 'msg']])

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


$BODY$;