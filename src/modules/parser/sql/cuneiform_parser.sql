CREATE TYPE corpus_parsed_unencoded_type AS (
    transliteration_id integer,
    sign_no integer,
    value text,
    sign_spec text,
    type @extschema:cuneiform_sign_properties@.sign_type,
    line_no_code integer,
    start_col_code integer,
    stop_col_code integer
);

CREATE TYPE errors_type AS (
    transliteration_id integer,
    line integer,
    col integer,
    symbol text,
    message text
);


CREATE TYPE sections_parser_type AS (
    section_name text,
    composition text
);

CREATE TYPE compounds_parser_type AS (
    pn_type @extschema:cuneiform_sign_properties@.pn_type,
    language @extschema:cuneiform_sign_properties@.language,
    section_no integer,
    comment text
);

CREATE TYPE words_parser_type AS (
    compound_no integer,
    capitalized boolean
);

CREATE TYPE surfaces_parser_type AS (
    surface @extschema:cuneiform_create_corpus@.surface_type, 
    data text,
    comment text
);

CREATE TYPE blocks_parser_type AS (
    surface_no integer, 
    block @extschema:cuneiform_create_corpus@.block_type, 
    data text, 
    comment text
);

CREATE TYPE lines_parser_type AS (
    block_no integer, 
    line text, 
    comment text
);

CREATE TYPE corpus_parser_type AS (
    line_no integer, 
    word_no integer, 
    value text, 
    sign_spec text, 
    type @extschema:cuneiform_sign_properties@.sign_type,  
    indicator_type @extschema:cuneiform_sign_properties@.indicator_type,
    phonographic boolean,
    condition @extschema:cuneiform_sign_properties@.sign_condition,
    stem boolean,
    crits text, 
    comment text,
    newline boolean,
    inverted boolean,
    ligature boolean,
    start_col integer,
    stop_col integer,
    line_no_code integer, 
    start_col_code integer, 
    stop_col_code integer
);

CREATE TYPE errors_parser_type AS (
    line_no integer, 
    "column" integer, 
    symbol text, 
    msg text
);



CREATE OR REPLACE PROCEDURE parse (
        code text, 
        schema text,
        id integer
    )
    LANGUAGE PLPYTHON3U
    AS $BODY$

from cuneiformparser import parseText
import pandas as pd

corpus_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.corpus 
    SELECT 
        $1, 
        ordinality::integer-1, 
        line_no, 
        word_no, 
        NULL, 
        NULL, 
        CASE WHEN type = 'value' OR type = 'sign' THEN NULL ELSE value END, 
        type, 
        indicator_type, 
        phonographic, 
        stem, 
        condition, 
        crits, 
        comment, 
        newline, 
        inverted, 
        ligature
    FROM
        UNNEST($2) WITH ORDINALITY
    """,
    ['integer', '@extschema@.corpus_parser_type[]']
)

corpus_unencoded_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.corpus_parsed_unencoded
    SELECT
        $1,
        ordinality::integer-1, 
        value, 
        sign_spec, 
        type,
        line_no_code,
        start_col_code,
        stop_col_code
    FROM
        UNNEST($2) WITH ORDINALITY
    WHERE
        type = 'value' OR type = 'sign'
        """, 
    ['integer', '@extschema@.corpus_parser_type[]']
)

words_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.words 
    SELECT 
        $1, 
        ordinality::integer-1, 
        compound_no, 
        capitalized
    FROM
        UNNEST($2) WITH ORDINALITY
    """,
    ['integer', '@extschema@.words_parser_type[]']
)

compounds_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.compounds 
    SELECT 
        $1, 
        ordinality::integer-1, 
        pn_type,
        language,
        section_no,
        comment
    FROM
        UNNEST($2) WITH ORDINALITY
    """,
    ['integer', '@extschema@.compounds_parser_type[]']
)

sections_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.sections 
    SELECT 
        $1, 
        ordinality::integer-1, 
        section_name, 
        composition_id
    FROM
        UNNEST($2) WITH ORDINALITY
        LEFT JOIN @extschema:cuneiform_corpus@.compositions ON composition_name = composition
    """,
    ['integer', '@extschema@.sections_parser_type[]']
)

surfaces_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.surfaces 
    SELECT 
        $1, 
        ordinality::integer-1, 
        surface, 
        data,
        comment
    FROM
        UNNEST($2) WITH ORDINALITY
    """,
    ['integer', '@extschema@.surfaces_parser_type[]']
)

blocks_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.blocks 
    SELECT 
        $1, 
        ordinality::integer-1, 
        surface_no,
        block, 
        data,
        comment
    FROM
        UNNEST($2) WITH ORDINALITY
    """,
    ['integer', '@extschema@.blocks_parser_type[]']
)

lines_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.lines 
    SELECT 
        $1, 
        ordinality::integer-1, 
        block_no, 
        line,
        comment
    FROM
        UNNEST($2) WITH ORDINALITY
    """,
    ['integer', '@extschema@.lines_parser_type[]']
)

errors_plan = plpy.prepare(
    f"""
    INSERT INTO {schema}.errors 
    SELECT 
        $1, 
        line_no, 
        "column", 
        symbol, 
        msg
    FROM
        UNNEST($2)
    """,
    ['integer', '@extschema@.errors_parser_type[]']
)

surfaces, blocks, lines, signs, compounds, words, sections, errors = parseText(code)

plpy.execute(f"DELETE FROM {schema}.corpus_parsed_unencoded WHERE transliteration_id = {id}")

plpy.execute(sections_plan, [id, list(sections.to_records(index=False))])
plpy.execute(compounds_plan, [id, [(x[0], x[1], x[2] if x[2] is not pd.NA else None, x[3]) for x in compounds.itertuples(index=False)]])
plpy.execute(words_plan, [id, list(words.to_records(index=False))])

plpy.execute(surfaces_plan, [id, list(surfaces.to_records(index=False))])
plpy.execute(blocks_plan, [id, list(blocks.to_records(index=False))])
plpy.execute(lines_plan, [id, list(lines.to_records(index=False))])

signs_tup = list(signs.to_records(index=False))
plpy.execute(corpus_plan, [id, signs_tup])
plpy.execute(corpus_unencoded_plan, [id, signs_tup])

plpy.execute(errors_plan, [id, list(errors.to_records(index=False))])

plpy.execute(f"""
    UPDATE {schema}.corpus SET 
        value_id = a.value_id, 
        sign_variant_id = a.sign_variant_id 
    FROM 
        {schema}.corpus_encoder a 
    WHERE 
        corpus.transliteration_id = a.transliteration_id AND 
        corpus.transliteration_id = {id} AND
        corpus.sign_no = a.sign_no
    """)

plpy.execute(f"""
    DELETE FROM {schema}.corpus_parsed_unencoded
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
        {schema}.corpus_parsed_unencoded
    WHERE
        corpus.transliteration_id = corpus_parsed_unencoded.transliteration_id AND
        corpus.transliteration_id = {id} AND
        corpus.sign_no = corpus_parsed_unencoded.sign_no;
    """)

$BODY$;