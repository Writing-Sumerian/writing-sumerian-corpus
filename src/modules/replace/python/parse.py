from py2plpy import plpy, InOut, sql_properties

class language:
    pass

@sql_properties(procedure=True)
def parse_replacement(code: str, language : language, stemmed: bool, id: InOut[int]):
    from cuneiformparser import parse
    import pandas as pd

    corpus_plan = plpy.prepare(
        f"INSERT INTO replace_pattern_corpus VALUES ($1, $2, $3, NULL, NULL, CASE WHEN $5 = 'value' OR $5 = 'sign' THEN NULL ELSE $4 END, $5, $6, $7, $8)", 
        ['integer', 'integer', 'integer', 'text', 'sign_type', 'indicator_type', 'boolean', 'boolean']
    )

    corpus_unencoded_plan = plpy.prepare(
        f'INSERT INTO replace_pattern_corpus_unencoded VALUES ($1, $2, $3, $4, $5)', 
        ['integer', 'integer', 'text', 'text', 'sign_type']
    )

    words_plan = plpy.prepare(
        f'INSERT INTO replace_pattern_words VALUES ($1, $2, $3, $4)',
        ['integer', 'integer', 'integer', 'boolean']
    )

    compounds_plan = plpy.prepare(
        f'INSERT INTO replace_pattern_compounds VALUES ($1, $2, $3, $4)',
        ['integer', 'integer', 'pn_type', 'language']
    )

    id = plpy.execute("SELECT nextval('@extschema@.replace_id_seq') AS id")[0]['id']

    signs, compounds, words, _, errors = parse(code, 'sumerian', stemmed)

    plpy.execute(f"DELETE FROM replace_pattern_corpus_unencoded WHERE pattern_id = {id}")

    for ix, row in compounds.iterrows():
        plpy.execute(compounds_plan, [id, ix]+[row[key] if row[key] is not pd.NA else None for key in ['pn_type', 'language']])
    for ix, row in words.iterrows():
        plpy.execute(words_plan, [id, ix]+[row[key] for key in ['compound_no', 'capitalized']])
    for ix, row in signs.iterrows():
        plpy.execute(corpus_plan, [id, ix]+[row[key] for key in ['word_no', 'value', 'type', 'indicator_type', 'phonographic', 'stem']])
    for ix, row in signs.iterrows():
        if row['type'] in ['value', 'sign'] or (row['type'] == 'number' and row['sign_spec'] is not None):
            plpy.execute(corpus_unencoded_plan, [id, ix]+[row[key] for key in ['value', 'sign_spec', 'type']])

    plpy.execute(f"""
        UPDATE replace_pattern_corpus SET 
            value_id = a.value_id, 
            sign_variant_id = a.sign_variant_id 
        FROM 
            replace_pattern_corpus_encoder a 
        WHERE 
            replace_pattern_corpus.pattern_id = a.pattern_id AND 
            replace_pattern_corpus.pattern_id = {id} AND
            replace_pattern_corpus.sign_no = a.sign_no
        """)

    return {'id': id}