CREATE TYPE sign_variant_type AS ENUM (
    'default',
    'nondefault',
    'reduced',
    'augmented',
    'nonstandard'
);


CREATE TABLE glyphs (
    glyph_id serial PRIMARY KEY,
    glyph text NOT NULL UNIQUE,
    unicode text
);

CREATE TABLE glyph_synonyms (
    synonym text PRIMARY KEY,
    glyph_id integer NOT NULL REFERENCES glyphs (glyph_id) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE graphemes (
    grapheme_id serial PRIMARY KEY,
    grapheme text NOT NULL UNIQUE,
    mzl_no integer
);

CREATE TABLE allographs (
    allograph_id serial PRIMARY KEY,
    grapheme_id integer NOT NULL REFERENCES graphemes (grapheme_id) DEFERRABLE INITIALLY IMMEDIATE,
    glyph_id integer NOT NULL REFERENCES glyphs (glyph_id) DEFERRABLE INITIALLY IMMEDIATE,
    variant_type sign_variant_type NOT NULL,
    specific boolean NOT NULL,
    UNIQUE (grapheme_id, glyph_id),
    CHECK (specific OR variant_type != 'default')
);

CREATE TABLE signs (
    sign_id serial PRIMARY KEY
);

CREATE TABLE allomorphs (
    allomorph_id serial PRIMARY KEY,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY IMMEDIATE,
    variant_type sign_variant_type NOT NULL,
    specific boolean NOT NULL,
    CHECK (specific OR variant_type != 'default')
);

CREATE TABLE allomorph_components (
    allomorph_id integer REFERENCES allomorphs (allomorph_id) DEFERRABLE INITIALLY IMMEDIATE,
    pos integer,
    grapheme_id integer NOT NULL REFERENCES graphemes (grapheme_id) DEFERRABLE INITIALLY IMMEDIATE,
    PRIMARY KEY (allomorph_id, pos)
);

CREATE TABLE values (
    value_id serial PRIMARY KEY,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY IMMEDIATE,
    main_variant_id integer NOT NULL,
    phonographic boolean
);

CREATE TABLE value_variants (
    value_variant_id serial PRIMARY KEY,
    value_id integer NOT NULL REFERENCES values (value_id) DEFERRABLE INITIALLY IMMEDIATE,
    value text NOT NULL,
    UNIQUE (value_variant_id, value_id),  -- pointless, but required for foreign key on values
    UNIQUE (value_variant_id, value)
);

CREATE TABLE glyph_values (
    value text PRIMARY KEY,
    value_id integer NOT NULL REFERENCES values (value_id) DEFERRABLE INITIALLY IMMEDIATE,
    glyph_ids integer[] NOT NULL
);

ALTER TABLE values ADD FOREIGN KEY (value_id, main_variant_id) REFERENCES value_variants (value_id, value_variant_id) DEFERRABLE INITIALLY DEFERRED;

CREATE UNIQUE INDEX ON allomorphs (sign_id) 
WHERE 
    variant_type = 'default';

CREATE UNIQUE INDEX ON allographs (grapheme_id) 
WHERE 
    variant_type = 'default';

CREATE UNIQUE INDEX ON allographs (glyph_id)
WHERE
    specific;

CREATE UNIQUE INDEX ON value_variants (value)
WHERE
    value NOT LIKE '%x';

CREATE INDEX value_index ON value_variants (value);

SELECT pg_catalog.pg_extension_config_dump('signs', '');
SELECT pg_catalog.pg_extension_config_dump('allomorphs', '');
SELECT pg_catalog.pg_extension_config_dump('allomorph_components', '');
SELECT pg_catalog.pg_extension_config_dump('glyphs', '');
SELECT pg_catalog.pg_extension_config_dump('glyph_synonyms', '');
SELECT pg_catalog.pg_extension_config_dump('glyph_values', '');
SELECT pg_catalog.pg_extension_config_dump('graphemes', '');
SELECT pg_catalog.pg_extension_config_dump('allographs', '');
SELECT pg_catalog.pg_extension_config_dump('values', '');
SELECT pg_catalog.pg_extension_config_dump('value_variants', '');