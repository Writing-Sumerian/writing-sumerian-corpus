CREATE TYPE sign_variant_type AS ENUM (
    'default',
    'nondefault',
    'reduced',
    'augmented',
    'nonstandard'
);

CREATE OR REPLACE FUNCTION merge_variant_types (
  a sign_variant_type,
  b sign_variant_type
  )
  RETURNS sign_variant_type
  LANGUAGE 'sql'
  STABLE
  STRICT
  AS $BODY$
  SELECT CASE
    WHEN a = b THEN a
    WHEN GREATEST(a, b) = ANY('{reduced, augmented}') AND LEAST(a, b) = 'default' THEN GREATEST(a, b)
    WHEN GREATEST(a, b) = ANY('{nonstandard, reduced, augmented}') THEN 'nonstandard'::sign_variant_type
    ELSE 'nondefault'::sign_variant_type
    END;
$BODY$;


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
    UNIQUE (grapheme_id, glyph_id)
);

CREATE TABLE signs (
    sign_id serial PRIMARY KEY
);

CREATE TABLE allomorphs (
    allomorph_id serial PRIMARY KEY,
    sign_id integer NOT NULL REFERENCES signs (sign_id) DEFERRABLE INITIALLY IMMEDIATE,
    variant_type sign_variant_type NOT NULL,
    specific boolean NOT NULL
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

CREATE TABLE sign_variants (
    sign_variant_id SERIAL PRIMARY KEY,
    allomorph_id integer NOT NULL REFERENCES allomorphs (allomorph_id) DEFERRABLE INITIALLY DEFERRED,
    allograph_ids integer[] NOT NULL,
    grapheme_ids integer[] NOT NULL,
    glyph_ids integer[] NOT NULL,
    variant_type sign_variant_type NOT NULL,
    specific boolean NOT NULL,
    UNIQUE (allomorph_id, allograph_ids)
);

CREATE VIEW sign_variants_view AS
WITH RECURSIVE 
    a AS (
        SELECT *
        FROM allomorph_components
        LEFT JOIN allographs USING (grapheme_id)
    ), 
    x(sign_id, allomorph_id, pos, allograph_ids, grapheme_ids, glyph_ids, variant_type, allomorph_variant_type, specific) AS (
        SELECT 
            sign_id,
            allomorph_id,
            a.pos,
            ARRAY[a.allograph_id],
            ARRAY[a.grapheme_id],
            ARRAY[a.glyph_id],
            merge_variant_types(a.variant_type, allomorphs.variant_type),
            allomorphs.variant_type,
            a.specific AND allomorphs.specific
        FROM a
            JOIN allomorphs USING (allomorph_id) 
        WHERE a.pos = 1
    UNION ALL
        SELECT
            sign_id,
            allomorph_id,
            a.pos,
            allograph_ids || allograph_id,
            grapheme_ids || grapheme_id,
            glyph_ids || glyph_id,
            merge_variant_types(a.variant_type, x.variant_type),
            allomorph_variant_type,
            a.specific AND x.specific
        FROM x
            JOIN a USING (allomorph_id)
        WHERE (x.pos + 1) = a.pos
    )
SELECT 
    allomorph_id,
    allograph_ids,
    grapheme_ids,
    glyph_ids,
    variant_type,
    specific
FROM (
    SELECT
        *,
        rank() OVER (PARTITION BY sign_id, glyph_ids ORDER BY variant_type, allomorph_variant_type, grapheme_ids ASC) AS rank2
    FROM (
        SELECT 
            *,
            rank() OVER (PARTITION BY x.allomorph_id ORDER BY x.pos DESC) AS rank1
        FROM x) _
    WHERE rank1 = 1) __
WHERE rank2 = 1;


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


CREATE VIEW glyph_identifiers (glyph_identifier, glyph_id) AS
SELECT
    upper(value),
    glyph_id
FROM
    value_variants
    JOIN values USING (value_id)
    JOIN allomorphs USING (sign_id)
    JOIN (
        SELECT
            allomorph_id,
            max(grapheme_id) AS grapheme_id
        FROM
            allomorph_components
        GROUP BY
            allomorph_id
        HAVING count(*) = 1
    ) c USING (allomorph_id)
    JOIN allographs USING (grapheme_id)
WHERE 
    allomorphs.variant_type = 'default'
    AND allographs.variant_type = 'default'
    AND value !~ 'x'
UNION
SELECT
    glyph,
    glyph_id
FROM
    glyphs
UNION
SELECT
    synonym,
    glyph_id
FROM 
    glyph_synonyms;

CREATE VIEW grapheme_identifiers (grapheme_identifier, grapheme_id) AS
SELECT
    upper(value),
    grapheme_id
FROM
    value_variants
    JOIN values USING (value_id)
    JOIN allomorphs USING (sign_id)
    JOIN (
        SELECT
            allomorph_id,
            max(grapheme_id) AS grapheme_id
        FROM
            allomorph_components
        GROUP BY
            allomorph_id
        HAVING count(*) = 1
    ) c USING (allomorph_id)
WHERE 
    variant_type = 'default'
    AND value !~ 'x'
UNION
SELECT
    glyph,
    grapheme_id
FROM
    glyphs
    JOIN allographs USING (glyph_id)
WHERE specific
UNION
SELECT
    grapheme,
    grapheme_id
FROM
    graphemes
UNION
SELECT
    synonym,
    grapheme_id
FROM 
    glyph_synonyms
    JOIN allographs USING (glyph_id)
WHERE specific;

CREATE VIEW sign_map (identifier, sign) AS
SELECT
    glyph_identifier,
    glyph
FROM
    glyph_identifiers
    JOIN glyphs USING (glyph_id)
UNION ALL
SELECT
    grapheme_identifier,
    grapheme
FROM
    grapheme_identifiers
    JOIN graphemes USING (grapheme_id)
WHERE
    grapheme_identifier NOT IN (SELECT glyph_identifier FROM glyph_identifiers);

CREATE VIEW sign_variants_text AS
SELECT
    sign_variant_id,
    allomorph_id,
    string_agg(grapheme, '.' ORDER BY ord) AS graphemes,
    string_agg(glyph, '.' ORDER BY ord) AS glyphs,
    string_agg(COALESCE(unicode, '□'), '' ORDER BY ord) AS unicode,
    variant_type,
    specific,
    count(*) AS length
FROM
    sign_variants
    LEFT JOIN LATERAL unnest(grapheme_ids, glyph_ids) WITH ORDINALITY AS a(grapheme_id, glyph_id, ord) ON TRUE
    LEFT JOIN graphemes USING (grapheme_id)
    LEFT JOIN glyphs USING (glyph_id)
GROUP BY
    sign_variant_id,
    allomorph_id,
    variant_type,
    specific;

CREATE VIEW signlist AS 
SELECT 
    sign_id, 
    sign_variant_id,
    graphemes,
    glyphs,
    unicode,
    sign_variants_text.variant_type,
    sign_variants_text.specific,
    value_id, 
    value_variant_id, 
    value, 
    value_variant_id = values.main_variant_id AS main 
FROM value_variants 
    JOIN values USING (value_id)
    JOIN allomorphs USING (sign_id) 
    JOIN sign_variants_text USING (allomorph_id)
ORDER BY 
    sign_id, 
    graphemes,
    glyphs,
    value_id, 
    main DESC,
    value;

CREATE OR REPLACE PROCEDURE add_value (
  sign_id integer, 
  value text,
  phonographic boolean DEFAULT NULL,
  value_id INOUT integer DEFAULT NULL,
  value_variant_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO values VALUES (default, sign_id, -1, phonographic) RETURNING values.value_id INTO value_id;
  INSERT INTO value_variants VALUES (default, value_id, value) RETURNING value_variants.value_variant_id INTO value_variant_id;
  UPDATE values SET main_variant_id = value_variant_id WHERE values.value_id = add_value.value_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_value (
  sign text, 
  value text,
  phonographic boolean DEFAULT NULL,
  value_id INOUT integer DEFAULT NULL,
  value_variant_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
  sign_id integer;
  BEGIN
  SELECT allomorphs.sign_id INTO sign_id FROM sign_variants_text JOIN allomorphs USING (allomorph_id) WHERE graphemes = sign AND sign_variants_text.specific;
  CALL add_value(sign_id, value, phonographic, value_id, value_variant_id);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allograph (
  grapheme_id integer,
  glyph_id integer,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allograph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO allographs VALUES (default, grapheme_id, glyph_id, variant_type, specific) RETURNING allographs.allograph_id INTO allograph_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allograph (
  grapheme text,
  glyph text,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allograph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    grapheme_id integer;
    glyph_id integer;
  BEGIN
  SELECT graphemes.grapheme_id INTO grapheme_id FROM graphemes WHERE graphemes.grapheme = add_allograph.grapheme;
  SELECT glyphs.glyph_id INTO glyph_id FROM glyphs WHERE glyphs.glyph = add_allograph.glyph;
  CALL add_allograph(grapheme_id, glyph_id, variant_type, specific, allograph_id);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allomorph (
  sign_id integer,
  graphemes text,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allomorph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO allomorphs VALUES (default, sign_id, variant_type, specific) RETURNING allomorphs.allomorph_id INTO allomorph_id;
  INSERT INTO allomorph_components
    SELECT
        allomorph_id,
        pos,
        grapheme_id
    FROM
        LATERAL regexp_split_to_table(graphemes, '\.') WITH ORDINALITY a(grapheme_identifier, pos)
        LEFT JOIN grapheme_identifiers USING (grapheme_identifier);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_allomorph (
  sign text, 
  graphemes text,
  variant_type sign_variant_type DEFAULT 'nondefault',
  specific boolean DEFAULT FALSE,
  allomorph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
  sign_id integer;
  BEGIN
  SELECT allomorphs.sign_id INTO sign_id FROM sign_variants_text JOIN allomorphs USING (allomorph_id) WHERE sign_variants_text.graphemes = sign AND sign_variants_text.specific;
  CALL add_allomorph(sign_id, graphemes, variant_type, specific, allomorph_id);
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE add_sign (
  graphemes text,
  sign_id INOUT integer DEFAULT NULL,
  allomorph_id INOUT integer DEFAULT NULL
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
  INSERT INTO signs VALUES (default) RETURNING signs.sign_id INTO sign_id;
  CALL add_allomorph(sign_id, graphemes, 'default', TRUE, allomorph_id);
  END;
$BODY$;


CREATE OR REPLACE PROCEDURE delete_value (
  value_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    DELETE FROM value_variants WHERE value_variants.value_id = delete_value.value_id;
    DELETE FROM values WHERE values.value_id = delete_value.value_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE delete_allomorph (
    allomorph_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    DELETE FROM sign_variants WHERE sign_variants.allomorph_id = delete_allomorph.allomorph_id;
    DELETE FROM allomorph_components WHERE allomorph_components.allomorph_id = delete_allomorph.allomorph_id;
    DELETE FROM allomorphs WHERE allomorphs.allomorph_id = delete_allomorph.allomorph_id;
  END;
$BODY$;


CREATE OR REPLACE PROCEDURE delete_grapheme (
    grapheme_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    DELETE FROM allographs WHERE allographs.grapheme_id = delete_grapheme.grapheme_id;
    DELETE FROM graphemes WHERE graphemes.grapheme_id = delete_grapheme.grapheme_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE delete_sign (
  sign_id integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    id integer;
  BEGIN
    FOR id IN SELECT value_id FROM values WHERE values.sign_id = delete_sign.sign_id LOOP
        CALL delete_value(id);
    END LOOP;
    FOR id IN SELECT allomorph_id FROM allomorphs WHERE allomorphs.sign_id = delete_sign.sign_id LOOP
        CALL delete_allomorph(id);
    END LOOP;
    DELETE FROM signs WHERE signs.sign_id = delete_sign.sign_id;
  END;
$BODY$;

CREATE OR REPLACE PROCEDURE merge_values (
  value_id_1 integer, 
  value_id_2 integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    same_sign bool;
  BEGIN
    SELECT a.sign_id = b.sign_id INTO same_sign FROM (SELECT sign_id FROM values WHERE value_id = value_id_1) a, (SELECT sign_id FROM values WHERE value_id = value_id_2) b; 
    ASSERT same_sign;
    UPDATE value_variants SET value_id = value_id_1 WHERE value_id = value_id_2;
    DELETE FROM values WHERE value_id = value_id_2;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE merge_signs (
  sign_id_1 integer, 
  sign_id_2 integer
  )
  LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    value_id integer;
  BEGIN
    FOR value_id IN 
        WITH value_list AS (
            SELECT * FROM value_variants JOIN values USING (value_id)
        )
        SELECT 
            a.value_id
        FROM value_list a 
            JOIN value_list b ON replace(a.value, 'x', '') = regexp_replace(b.value, '[0-9x]+$', '')
        WHERE 
            a.value ~ 'x' AND a.sign_id = sign_id_2 AND b.sign_id = sign_id_1
    LOOP
        CALL delete_value(value_id);
    END LOOP;
    FOR value_id IN 
        WITH value_list AS (
            SELECT * FROM value_variants JOIN values USING (value_id)
        )
        SELECT 
            a.value_id
        FROM value_list a 
            JOIN value_list b ON replace(a.value, 'x', '') = regexp_replace(b.value, '[0-9x]+$', '')
        WHERE 
            a.value ~ 'x' AND a.sign_id = sign_id_1 AND b.sign_id = sign_id_2
    LOOP
        CALL delete_value(value_id);
    END LOOP;
    UPDATE values SET sign_id = sign_id_1 where sign_id = sign_id_2;
    UPDATE allomorphs SET variant_type = 'nondefault' where sign_id = sign_id_2 AND variant_type = 'default';
    UPDATE allomorphs SET sign_id = sign_id_1 where sign_id = sign_id_2;
    DELETE FROM signs WHERE sign_id = sign_id_2;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE make_glyph_value (
    value_id integer,
    value_id_new integer
)
LANGUAGE PLPGSQL
  AS $BODY$
  BEGIN
    INSERT INTO glyph_values 
        SELECT 
            value, 
            value_id_new, 
            glyph_ids 
        FROM 
            value_variants 
            JOIN values USING (value_id) 
            JOIN allomorphs USING (sign_id) 
            JOIN sign_variants USING (allomorph_id)
        WHERE
            values.value_id = make_glyph_value.value_id AND 
            value !~ 'x' AND
            sign_variants.variant_type = 'default';
    CALL delete_value(value_id);
END;
$BODY$;


CREATE OR REPLACE PROCEDURE make_glyph_value (
    value text,
    value_new text
)
LANGUAGE PLPGSQL
  AS $BODY$
  DECLARE
    value_id integer;
    value_id_new integer;
  BEGIN
    SELECT value_variants.value_id INTO value_id FROM value_variants WHERE value_variants.value = make_glyph_value.value;
    SELECT value_variants.value_id INTO value_id_new FROM value_variants WHERE value_variants.value = make_glyph_value.value_new;
    CALL make_glyph_value(value_id, value_id_new);
END;
$BODY$;


CREATE OR REPLACE FUNCTION split_sign (
    sign text
    )
    RETURNS TABLE(component text, op text)
    LANGUAGE SQL
    IMMUTABLE
    STRICT
    AS $BODY$
    SELECT 
        regexp_split_to_table(sign, '([()+.&%×]|@[gštnkzi0-9]*)+'), 
        regexp_split_to_table(regexp_replace(sign, '^\(', 'V('), '[A-ZŠĜŘḪṬṢŚ’]+[x0-9]*(bis)?|(?<![@0-9])[0-9]+')
$BODY$;

CREATE OR REPLACE FUNCTION split_glyphs (
    sign text
    )
    RETURNS TABLE(glyph text)
    LANGUAGE PLPYTHON3U
    IMMUTABLE
    STRICT
    AS $BODY$
    j = 0
    level = 0
    for i, c in enumerate(sign):
        if c == '(':
            level += 1
        elif c == ')':
            level -= 1
        elif not level and c == '.':
            yield sign[j:i]
            j = i+1
    yield sign[j:]
$BODY$;


CREATE OR REPLACE PROCEDURE signlist_refresh_materialized_views ()
    LANGUAGE PLPGSQL
    AS 
$BODY$
    BEGIN

    CREATE TEMPORARY TABLE sign_variant_ids ON COMMIT DROP AS
        SELECT sign_variant_id, allomorph_id, allograph_ids FROM sign_variants;

    SET CONSTRAINTS ALL DEFERRED;
    DELETE FROM sign_variants;
    INSERT INTO sign_variants 
        SELECT
            COALESCE(sign_variant_id, nextval('sign_variants_sign_variant_id_seq')),
            allomorph_id,
            allograph_ids,
            grapheme_ids,
            glyph_ids,
            variant_type,
            specific
        FROM
            sign_variants_view
            LEFT JOIN sign_variant_ids USING (allomorph_id, allograph_ids);
    END
$BODY$;
