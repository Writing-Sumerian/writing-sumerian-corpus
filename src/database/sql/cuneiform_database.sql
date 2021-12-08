
-- Texts

CREATE TABLE texts_norm (
    text_id serial PRIMARY KEY,
    cdli_no text,
    bdtns_no text,
    citation text,
    provenience_id integer REFERENCES proveniences (provenience_id) DEFERRABLE INITIALLY IMMEDIATE,
    provenience_comment text,
    period_id integer REFERENCES periods (period_id) DEFERRABLE INITIALLY IMMEDIATE,
    period_comment text,
    genre_id integer REFERENCES genres (genre_id) DEFERRABLE INITIALLY IMMEDIATE,
    genre_comment text,
    date TABLETDATE,
    archive text
);


CREATE TABLE transliterations (
    transliteration_id serial PRIMARY KEY,
    text_id integer NOT NULL REFERENCES texts_norm (text_id) DEFERRABLE INITIALLY IMMEDIATE,
    object text NOT NULL,
    description text NOT NULL,
    UNIQUE (transliteration_id, object)
);


-- Compositions

CREATE TABLE compositions (
    composition_id SERIAL PRIMARY KEY,
    name text
);

CREATE TABLE sections (
    transliteration_id integer REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE,
    section_no integer,
    compound_no integer NOT NULL,
    composition_id integer REFERENCES compositions  DEFERRABLE INITIALLY IMMEDIATE,
    PRIMARY KEY (transliteration_id, section_no)
);


-- Corpus

CREATE TABLE compounds (
    transliteration_id integer REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE,
    compound_no integer,
    pn_type pn_type,
    language LANGUAGE,
    compound_comment text,
    PRIMARY KEY (transliteration_id, compound_no)
);

CREATE TABLE words (
    transliteration_id integer REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE,
    word_no integer,
    compound_no integer NOT NULL,
    capitalized boolean,
    PRIMARY KEY (transliteration_id, word_no),
    FOREIGN KEY (transliteration_id, compound_no) REFERENCES compounds (transliteration_id, compound_no) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TYPE surface_type AS ENUM (
    'obverse',
    'reverse',
    'top',
    'bottom',
    'left',
    'right',
    'seal',
    'surface'
);

CREATE TABLE surfaces (
    transliteration_id integer REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE,
    surface_no integer,
    surface_type surface_type,
    surface_data text,
    surface_comment text,
    PRIMARY KEY (transliteration_id, surface_no)
);

CREATE TYPE block_type AS ENUM (
    'column',
    'summary',
    'date',
    'caption',
    'legend',
    'bottom_column',
    'block'
);

CREATE TABLE blocks (
    transliteration_id integer REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE,
    block_no integer,
    block_type block_type,
    block_data text,
    block_comment text,
    surface_no integer,
    PRIMARY KEY (transliteration_id, block_no),
    FOREIGN KEY (transliteration_id, surface_no) REFERENCES surfaces (transliteration_id, surface_no) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE lines (
    transliteration_id integer REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE,
    line_no integer,
    block_no integer,
    line text,
    line_comment text,
    PRIMARY KEY (transliteration_id, line_no),
    FOREIGN KEY (transliteration_id, block_no) REFERENCES blocks (transliteration_id, block_no) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE corpus_norm (
    transliteration_id integer REFERENCES transliterations DEFERRABLE INITIALLY IMMEDIATE,
    sign_no integer NOT NULL,
    line_no integer NOT NULL,
    word_no integer NOT NULL,
    orig_value text,
    value_id integer REFERENCES values DEFERRABLE INITIALLY IMMEDIATE,
    sign_id integer REFERENCES signs DEFERRABLE INITIALLY IMMEDIATE,
    properties SIGN_PROPERTIES NOT NULL,
    stem boolean,
    condition sign_condition NOT NULL,
    crits text,
    comment text,
    newline boolean NOT NULL,
    inverted boolean NOT NULL,
    PRIMARY KEY (transliteration_id, sign_no),
    FOREIGN KEY (transliteration_id, word_no) REFERENCES public.words (transliteration_id, word_no) DEFERRABLE INITIALLY IMMEDIATE,
    FOREIGN KEY (transliteration_id, line_no) REFERENCES public.lines (transliteration_id, line_no) DEFERRABLE INITIALLY IMMEDIATE
);


-- Views

CREATE MATERIALIZED VIEW corpus_composition AS (
SELECT 
    corpus_norm.transliteration_id,
    corpus_norm.sign_no,
    corpus_norm.word_no,
    corpus_norm.line_no,
    row_number() OVER (PARTITION BY corpus_norm.transliteration_id ORDER BY corpus_norm.sign_no, sign_composition.pos) AS component_no,
    coalesce(sign_composition.pos, 1) AS pos,
    sign_composition.component_sign_id,
    coalesce(sign_composition.initial, TRUE) AS initial,
    coalesce(sign_composition.final, TRUE) AS final,
    corpus_norm.properties
   FROM corpus_norm
     LEFT JOIN sign_composition USING (sign_id)
  ORDER BY corpus_norm.transliteration_id, corpus_norm.sign_no, sign_composition.pos
);

CREATE VIEW texts AS
SELECT 
    texts_norm.*,
    periods.name AS period,
    COALESCE(proveniences.name, proveniences.modern_name) AS provenience,
    genres.name AS genre
FROM
    texts_norm
    LEFT JOIN periods USING (period_id)
    LEFT JOIN proveniences USING (provenience_id)
    LEFT JOIN genres USING (genre_id);

CREATE VIEW corpus AS
SELECT
    *
FROM
    corpus_norm
    LEFT JOIN words USING (transliteration_id, word_no)
    LEFT JOIN compounds USING (transliteration_id, compound_no)
    LEFT JOIN lines USING (transliteration_id, line_no)
    LEFT JOIN signs USING (sign_id)
    LEFT JOIN (SELECT value_id, main_variant_id AS value_variant_id, phonographic FROM values) _ USING (value_id)
    LEFT JOIN value_variants USING (value_id, value_variant_id);


-- Performance

CREATE INDEX ON texts_norm(provenience_id);
CREATE INDEX ON texts_norm(period_id);
CREATE INDEX ON texts_norm(genre_id);

CREATE INDEX ON corpus_norm (value_id);
CREATE INDEX ON corpus_composition (component_sign_id);
CREATE INDEX ON corpus_composition (transliteration_id, sign_no);
CREATE UNIQUE INDEX ON corpus_composition (transliteration_id, component_no);

ALTER TABLE corpus_norm ALTER COLUMN value_id SET STATISTICS 1000;
ALTER MATERIALIZED VIEW corpus_composition ALTER COLUMN component_sign_id SET STATISTICS 1000;