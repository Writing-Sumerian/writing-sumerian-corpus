CREATE OR REPLACE FUNCTION reload ()
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE
    AS $BODY$
    
BEGIN


DELETE FROM corpus;

DELETE FROM words;

DELETE FROM compounds;

DELETE FROM texts;


-- texts

CREATE TEMPORARY TABLE textids_tmp_ (
    text_id serial,
    identifier text
);

CREATE TEMPORARY TABLE texts_tmp_ (
    identifier text,
    cdli_no text,
    bdtns_no integer,
    citation text,
    source text,
    core_corpus boolean,
    provenience text,
    provenience_comment text,
    period text,
    period_comment text,
    king text,
    y text,
    m text,
    d text,
    archive text,
    genre text,
    seal text
);

COPY texts_tmp_
FROM
    '{{path}}/texts'
    NULL '';

INSERT INTO textids_tmp_ (identifier)
SELECT
    identifier
FROM texts_tmp_;

INSERT INTO texts (text_id, cdli_no, bdtns_no, citation, source, core_corpus, provenience_id, provenience_comment, period_id, period_comment, date, archive, genre, seal)
SELECT
    text_id,
    cdli_no,
    bdtns_no,
    citation,
    source,
    core_corpus,
    provenience_id,
    provenience_comment,
    period_id,
    period_comment,
    null, --TABLEDATE (king, y, m, d),
    archive,
    genre,
    seal
FROM
    texts_tmp_
    JOIN textids_tmp_ USING (identifier)
    LEFT JOIN periods ON (period = periods.name)
    LEFT JOIN proveniences ON (provenience = proveniences.name);

DROP TABLE texts_tmp_;


-- compounds

CREATE TEMPORARY TABLE compounds_tmp_ (
    identifier text,
    compound_no integer,
    comment text
);

COPY compounds_tmp_
FROM
    '{{path}}/compounds';

INSERT INTO public.compounds 
SELECT
    text_id,
    compound_no,
    comment
FROM
    compounds_tmp_
    JOIN textids_tmp_ USING (identifier);

DROP TABLE compounds_tmp_;


-- words

CREATE TEMPORARY TABLE words_tmp_ (
    identifier text,
    word_no integer,
    compound_no integer,
    pn boolean,
    language language
);

COPY words_tmp_
FROM
    '{{path}}/words';

INSERT INTO public.words 
SELECT
    text_id,
    word_no,
    compound_no,
    pn,
    language
FROM
    words_tmp_
    JOIN textids_tmp_ USING (identifier);

DROP TABLE words_tmp_;


-- corpus

CREATE TEMPORARY TABLE corpus_tmp_ (
        identifier text,
        sign_no integer NOT NULL,
        line_no integer NOT NULL,
        word_no integer NOT NULL,
        value text,
        type SIGN_TYPE,
        indicator boolean,
        alignment ALIGNMENT,
        phonographic boolean,
        condition sign_condition,
        crits text,
        comment text,
        newline boolean,
        inverted boolean
);

COPY corpus_tmp_
FROM
    '{{path}}/corpus'
    NULL '';

DROP INDEX corpus_sign_id_idx;

DROP INDEX corpus_value_id_idx;

INSERT INTO corpus
SELECT
    text_id,
    sign_no,
    line_no,
    word_no,
    corpus_tmp_.value,
    value_id,
    sign_id,
    (type, indicator,  alignment, phonographic)::sign_properties,
    TRUE,
    condition,
    crits,
    comment,
    newline,
    inverted
FROM
    corpus_tmp_
    JOIN textids_tmp_ USING (identifier)
    LEFT JOIN value_variants ON (value_variants.value = lower(corpus_tmp_.value))
    LEFT JOIN values USING (value_id);

CREATE INDEX corpus_sign_id_idx ON corpus (sign_id);

CREATE INDEX corpus_value_id_idx ON corpus (value_id);

DROP TABLE corpus_tmp_;


DROP TABLE textids_tmp_;


END

$BODY$;