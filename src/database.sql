DROP TABLE public.corpus;
DROP TYPE public.sign_properties;
DROP TYPE public.sign_type;
DROP TYPE public.alignment;
DROP TYPE public.language;

DROP TABLE public.compounds;
DROP TABLE public.words;

DROP TABLE public.texts;
DROP TABLE public.proveniences;
DROP TABLE public.periods;
DROP TYPE public.tabletdate;

DROP TABLE public.value_variants;
DROP TABLE public.values;
DROP TABLE public.signs;


-- Sign List

CREATE TABLE public.signs (
    sign_id SERIAL PRIMARY KEY,
    name TEXT UNIQUE
);

CREATE TABLE public.values (
    value_id SERIAL PRIMARY KEY,
    sign_id INTEGER REFERENCES public.signs(sign_id)
);

CREATE TABLE public.value_variants (
    value_variant_id SERIAL PRIMARY KEY,
    value_id INTEGER REFERENCES public.values(value_id),
    value TEXT,
    main BOOLEAN
);


-- Texts

CREATE TYPE public.tabletdate AS (
    king TEXT,
    y TEXT,
    m TEXT,
    d TEXT
);

CREATE TABLE public.periods (
    period_id SERIAL PRIMARY KEY,
    name TEXT UNIQUE,
    years INT4RANGE,
    super INTEGER REFERENCES public.periods(period_id)
);

CREATE TABLE public.proveniences (
    provenience_id SERIAL PRIMARY KEY,
    name TEXT UNIQUE
);

CREATE TABLE public.texts (
    text_id SERIAL PRIMARY KEY,
    cdli_no TEXT,
    bdtns_no INTEGER,
    citation TEXT,
    core_corpus BOOLEAN,
    source TEXT,
    provenience_id INTEGER REFERENCES public.proveniences(provenience_id),
    provenience_comment TEXT,
    period_id INTEGER REFERENCES public.periods(period_id),
    period_comment TEXT,
    date TABLETDATE,
    archive TEXT,
    genre TEXT,
    seal TEXT
);


-- Corpus

CREATE TABLE public.compounds (
    text_id INTEGER REFERENCES public.texts,
    compound_no INTEGER,
    comment TEXT,
    PRIMARY KEY (text_id, compound_no)
);


CREATE TYPE language AS ENUM ('sumerian', 'akkadian', 'other');

CREATE TABLE public.words (
    text_id INTEGER REFERENCES public.texts,
    word_no INTEGER,
    compound_no INTEGER,
    pn BOOLEAN,
    language LANGUAGE,
    PRIMARY KEY (text_id, word_no),
    FOREIGN KEY (text_id, compound_no) REFERENCES public.compounds(text_id, compound_no)
);


CREATE TYPE sign_type AS ENUM ('value', 'sign', 'number', 'punctuation', 'desc', 'damage');
CREATE TYPE alignment AS ENUM ('left', 'right', 'center');
CREATE TYPE sign_condition AS ENUM ('intact', 'damaged', 'lost', 'inserted', 'deleted');

CREATE TYPE sign_properties AS (
    type SIGN_TYPE,
    indicator BOOLEAN,
    alignment ALIGNMENT,
    phonographic BOOLEAN
);

CREATE TABLE public.corpus (
    text_id INTEGER REFERENCES texts,
    sign_no INTEGER NOT NULL,
    line_no INTEGER NOT NULL,
    word_no INTEGER NOT NULL,
    orig_value TEXT NOT NULL,
    value_id INTEGER REFERENCES values,
    sign_id INTEGER REFERENCES signs,
    properties SIGN_PROPERTIES NOT NULL,
    stem boolean,
    condition sign_condition NOT NULL,
    crits text,
    comment text,
    newline boolean NOT NULL,
    inverted boolean NOT NULL,
    PRIMARY KEY (text_id, sign_no),
    FOREIGN KEY (text_id, word_no) REFERENCES public.words(text_id, word_no)
);

CREATE INDEX corpus_sign_id_idx ON corpus (sign_id);

CREATE INDEX corpus_value_id_idx ON corpus (value_id);