CREATE SEQUENCE replace_id_seq CYCLE;

CREATE TABLE replace_pattern_corpus (
    pattern_id integer,
    sign_no integer,
    word_no integer,
    value_id integer,
    sign_variant_id integer,
    custom_value text,
    type sign_type,
    indicator_type indicator_type,
    phonographic boolean,
    stem boolean,
    PRIMARY KEY (pattern_id, sign_no)
);

CREATE TABLE replace_pattern_words (
    pattern_id integer,
    word_no integer,
    compound_no integer,
    capitalized boolean,
    PRIMARY KEY (pattern_id, word_no)
);

CREATE TABLE replace_pattern_compounds (
    pattern_id integer,
    compound_no integer,
    pn_type pn_type,
    language language,
    PRIMARY KEY (pattern_id, compound_no)
);

CREATE TABLE replace_pattern_corpus_unencoded (
    pattern_id integer,
    sign_no integer,
    value text,
    sign_spec text,
    type sign_type NOT NULL,
    PRIMARY KEY (pattern_id, sign_no)
);

CREATE TYPE corpus_replace_type AS (
    transliteration_id integer,
    sign_no integer,
    line_no integer,
    word_no integer,
    value_id integer,
    sign_variant_id integer,
    custom_value text,
    type sign_type,
    indicator_type indicator_type,
    phonographic boolean,
    stem boolean,
    condition sign_condition,
    crits text,
    comment text,
    newline boolean,
    inverted boolean,
    ligature boolean,
    pattern_id integer,
    pattern_word boolean,
    word_no_ref integer,
    pattern_compound boolean,
    compound_no_ref integer,
    valid boolean
);

CALL create_corpus_encoder('replace_pattern_corpus_encoder', 'replace_pattern_corpus_unencoded', '{pattern_id}');
