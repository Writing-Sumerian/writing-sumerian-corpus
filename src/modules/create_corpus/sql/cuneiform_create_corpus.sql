
CREATE TYPE witness_type AS ENUM (
    'original',
    'print',
    'copy',
    'variant'
);

CREATE TYPE surface_type AS ENUM (
    'obverse',
    'reverse',
    'top',
    'bottom',
    'left',
    'right',
    'fragment',
    'surface'
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


CREATE OR REPLACE PROCEDURE create_corpus (schema text)
    LANGUAGE PLPGSQL
    AS 
$BODY$

BEGIN

EXECUTE format(
    $$
    CREATE TABLE %1$I.sections (
        transliteration_id integer,
        section_no integer,
        section_name text NOT NULL,
        composition_id integer NOT NULL,
        witness_type witness_type NOT NULL,
        PRIMARY KEY (transliteration_id, section_no)
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.compounds (
        transliteration_id integer,
        compound_no integer,
        pn_type pn_type,
        language LANGUAGE,
        section_no integer,
        compound_comment text,
        PRIMARY KEY (transliteration_id, compound_no),
        FOREIGN KEY (transliteration_id, section_no) REFERENCES %1$I.sections (transliteration_id, section_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.words (
        transliteration_id integer,
        word_no integer,
        compound_no integer NOT NULL,
        capitalized boolean,
        PRIMARY KEY (transliteration_id, word_no),
        FOREIGN KEY (transliteration_id, compound_no) REFERENCES %1$I.compounds (transliteration_id, compound_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.surfaces (
        transliteration_id integer,
        surface_no integer,
        surface_type surface_type NOT NULL,
        surface_data text,
        surface_comment text,
        PRIMARY KEY (transliteration_id, surface_no)
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.blocks (
        transliteration_id integer,
        block_no integer,
        surface_no integer NOT NULL,
        block_type block_type NOT NULL,
        block_data text,
        block_comment text,
        PRIMARY KEY (transliteration_id, block_no),
        FOREIGN KEY (transliteration_id, surface_no) REFERENCES %1$I.surfaces (transliteration_id, surface_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.lines (
        transliteration_id integer,
        line_no integer,
        block_no integer NOT NULL,
        line text,
        line_comment text,
        PRIMARY KEY (transliteration_id, line_no),
        FOREIGN KEY (transliteration_id, block_no) REFERENCES %1$I.blocks (transliteration_id, block_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

EXECUTE format(
    $$
    CREATE TABLE %1$I.corpus (
        transliteration_id integer,
        sign_no integer,
        line_no integer NOT NULL,
        word_no integer NOT NULL,
        value_id integer REFERENCES values DEFERRABLE INITIALLY IMMEDIATE,
        sign_variant_id integer REFERENCES sign_variants DEFERRABLE INITIALLY IMMEDIATE,
        custom_value text,
        type sign_type NOT NULL,
        indicator_type indicator_type,
        phonographic boolean,
        stem boolean,
        condition sign_condition NOT NULL,
        crits text,
        comment text,
        newline boolean NOT NULL,
        inverted boolean NOT NULL,
        ligature boolean NOT NULL,
        PRIMARY KEY (transliteration_id, sign_no),
        FOREIGN KEY (transliteration_id, word_no) REFERENCES %1$I.words (transliteration_id, word_no) DEFERRABLE INITIALLY IMMEDIATE,
        FOREIGN KEY (transliteration_id, line_no) REFERENCES %1$I.lines (transliteration_id, line_no) DEFERRABLE INITIALLY IMMEDIATE
    )
    $$,
    schema);

END;

$BODY$;