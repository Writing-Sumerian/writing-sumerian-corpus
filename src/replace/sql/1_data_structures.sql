CREATE SCHEMA replace;

CREATE TABLE replace.corpus_pattern (
    pattern_id integer,
    sign_no integer,
    word_no integer,
    value_id integer,
    sign_variant_id integer,
    custom_value text,
    properties sign_properties,
    stem boolean,
    PRIMARY KEY (pattern_id, sign_no)
);

CREATE TABLE replace.words_pattern (
    pattern_id integer,
    word_no integer,
    compound_no integer,
    capitalized boolean,
    PRIMARY KEY (pattern_id, word_no)
);

CREATE TABLE replace.compounds_pattern (
    pattern_id integer,
    compound_no integer,
    pn_type pn_type,
    language language,
    PRIMARY KEY (pattern_id, compound_no)
);

CREATE TABLE corpus_unencoded_pattern (
    pattern_id integer,
    sign_no integer,
    value text,
    sign_spec text,
    type sign_type NOT NULL,
    PRIMARY KEY (pattern_id, sign_no)
);

CALL create_corpus_encoder('replace_corpus_encoder', 'corpus_unencoded_pattern', '{pattern_id}');


CREATE TABLE replace.corpus (
    LIKE corpus,
    pattern_id integer,
    pattern_word boolean,
    word_no_ref integer,
    pattern_compound boolean,
    compound_no_ref integer,
    valid boolean
);

CREATE VIEW replace.words AS 
WITH x AS (
    SELECT
        transliteration_id,
        pattern_id,
        word_no,
        pattern_word,
        word_no_ref,
        sum((compound_no_ref IS NOT NULL)::integer) OVER (PARTITION BY transliteration_id ORDER BY sign_no) - 1 AS compound_no
    FROM
        replace.corpus
    WHERE
        word_no_ref IS NOT NULL
)
SELECT
    x.transliteration_id,
    x.word_no,
    x.compound_no,
    COALESCE(a.capitalized, b.capitalized) AS capitalized
FROM
    x
    LEFT JOIN words a ON (NOT pattern_word AND x.transliteration_id = a.transliteration_id AND x.word_no_ref = a.word_no)
    LEFT JOIN replace.words_pattern b ON (pattern_word AND x.pattern_id = b.pattern_id AND x.word_no_ref = b.word_no);


CREATE VIEW replace.compounds AS
WITH x AS (
    SELECT
        transliteration_id,
        pattern_id,
        row_number() OVER (PARTITION BY transliteration_id ORDER BY sign_no) - 1 AS compound_no,
        pattern_compound,
        compound_no_ref
    FROM
        replace.corpus
    WHERE
        compound_no_ref IS NOT NULL   
)
SELECT
    x.transliteration_id,
    x.compound_no,
    COALESCE(a.pn_type, b.pn_type) AS pn_type,
    COALESCE(a.language, b.language) AS language,
    a.section_no,
    a.compound_comment
FROM
    x
    LEFT JOIN compounds a ON (NOT pattern_compound AND x.transliteration_id = a.transliteration_id AND x.compound_no_ref = a.compound_no)
    LEFT JOIN replace.compounds_pattern b ON (pattern_compound AND x.pattern_id = b.pattern_id AND x.compound_no_ref = b.compound_no);


CREATE VIEW replace.lines AS SELECT * FROM lines;
CREATE VIEW replace.blocks AS SELECT * FROM blocks;
CREATE VIEW replace.surfaces AS SELECT * FROM surfaces;
CREATE VIEW replace.objects AS SELECT * FROM objects;
