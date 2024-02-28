
-- corpus

CREATE TABLE corpus_unencoded (
   transliteration_id integer,
    sign_no integer,
    value text,
    sign_spec text,
    type sign_type NOT NULL,
    PRIMARY KEY (transliteration_id, sign_no)
);

CREATE INDEX ON corpus_unencoded (type);


CREATE OR REPLACE VIEW corpus_unencoded_view AS
SELECT
    transliteration_id,
    sign_no,
    a[1] AS value,
    left(a[2], -1) AS sign_spec,
    type
FROM
    corpus
    LEFT JOIN LATERAL regexp_split_to_array(custom_value, '(?<=[0-9a-zA-ZŠšḪḫŘřĝĜṣṢṭṬ])\(') AS _(a) ON TRUE
WHERE
    custom_value IS NOT NULL
    AND (type = 'value' OR type = 'sign');

CALL create_corpus_encoder('corpus_encoder', 'corpus_unencoded', '{transliteration_id}');


CREATE OR REPLACE PROCEDURE encode_corpus ()
    LANGUAGE PLPGSQL
    AS $BODY$
    
BEGIN

UPDATE corpus SET 
    value_id = corpus_encoder.value_id, 
    sign_variant_id = corpus_encoder.sign_variant_id,
    custom_value = NULL
FROM
    corpus_encoder
WHERE
    corpus.sign_variant_id IS NULL
    AND corpus_encoder.sign_variant_id IS NOT NULL
    AND corpus.transliteration_id = corpus_encoder.transliteration_id
    AND corpus.sign_no = corpus_encoder.sign_no
    AND corpus.type = corpus_encoder.type;

DELETE FROM corpus_unencoded 
USING corpus 
WHERE 
    corpus.transliteration_id = corpus_unencoded.transliteration_id AND
    corpus.sign_no = corpus_unencoded.sign_no AND
    corpus.sign_variant_id IS NOT NULL;

END;

$BODY$;


CREATE OR REPLACE PROCEDURE unencode_corpus ()
    LANGUAGE PLPGSQL
    AS $BODY$
    
BEGIN

INSERT INTO corpus_unencoded 
SELECT
    transliteration_id,
    sign_no,
    COALESCE(value, graphemes),
    glyphs,
    type
FROM
    corpus 
    LEFT JOIN sign_variants_composition USING (sign_variant_id)
    LEFT JOIN values USING (value_id)
    LEFT JOIN value_variants ON (main_variant_id = value_variant_id)
WHERE
    sign_variant_id IS NOT NULL;

UPDATE corpus SET 
    value_id = NULL, 
    sign_variant_id = NULL
WHERE
    corpus.sign_variant_id IS NOT NULL;

END;

$BODY$;