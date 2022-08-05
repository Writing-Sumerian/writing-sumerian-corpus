CREATE OR REPLACE FUNCTION parse (
    code text, 
    corpus text, 
    compounds text,
    words text, 
    surfaces text,
    blocks text,
    lines text,
    errors text,
    language LANGUAGE,
    stemmed boolean)
    RETURNS text[]
    VOLATILE
    LANGUAGE 'plpython3u'
    AS $BODY$

from cuneiformparser import parseText
import pandas as pd


corpus_plan = plpy.prepare(
    f'INSERT INTO {corpus} VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)', 
    ['text', 'integer', 'integer', 'integer', 'text', 'text', 'sign_type', 'boolean', 'alignment', 'boolean', 'sign_condition', 'boolean', 'text', 'text', 'boolean', 'boolean', 'boolean']
)

words_plan = plpy.prepare(
    f'INSERT INTO {words} VALUES ($1, $2, $3, $4)',
    ['text', 'integer', 'integer', 'boolean']
)

compounds_plan = plpy.prepare(
    f'INSERT INTO {compounds} VALUES ($1, $2, $3, $4, $5, $6)',
    ['text', 'integer', 'pn_type', 'language', 'text', 'text']
)

surfaces_plan = plpy.prepare(
    f'INSERT INTO {surfaces} VALUES ($1, $2, $3, $4, $5)',
    ['text', 'integer', 'surface_type', 'text', 'text']
)

blocks_plan = plpy.prepare(
    f'INSERT INTO {blocks} VALUES ($1, $2, $3, $4, $5, $6)',
    ['text', 'integer', 'integer', 'block_type', 'text', 'text']
)

lines_plan = plpy.prepare(
    f'INSERT INTO {lines} VALUES ($1, $2, $3, $4, $5)',
    ['text', 'integer', 'integer', 'text', 'text']
)

objects_, surfaces_, blocks_, lines_, signs_, compounds_, words_, errors_ = parseText(code, language, stemmed)

for ix, row in signs_.iterrows():
    plpy.execute(corpus_plan, [signs_['object'].values[0], ix]+[signs_[key].values[0] for key in ['line_no', 'word_no', 'value', 'sign_spec', 'sign_type', 'indicator', 'alignment', 'phonographic', 'condition', 'stem', 'crits', 'comment', 'newline', 'inverted', 'ligature']])
for ix, row in words_.iterrows():
    plpy.execute(words_plan, [words_['object'].values[0], ix]+[words_[key].values[0] for key in ['compound_no', 'capitalized']])
for ix, row in compounds_.iterrows():
    plpy.execute(compounds_plan, [compounds_['object'].values[0], ix]+[compounds_[key].values[0] for key in ['pn_type', 'language', 'section', 'comment']])
for ix, row in surfaces_.iterrows():
    plpy.execute(surfaces_plan, [surfaces_['object'].values[0], ix]+[surfaces_[key].values[0] for key in ['surface', 'data', 'comment']])
for ix, row in blocks_.iterrows():
    plpy.execute(blocks_plan, [blocks_['object'].values[0], ix]+[blocks_[key].values[0] for key in ['surface_no', 'block', 'data', 'comment']])
for ix, row in lines_.iterrows():
    plpy.execute(lines_plan, [lines_['object'].values[0], ix]+[lines_[key].values[0] for key in ['block_no', 'line', 'comment']])

return objects_['object'].values

$BODY$;