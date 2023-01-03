CREATE OR REPLACE FUNCTION cun_agg_sfunc (
    internal, 
    text, 
    text,
    sign_variant_type, 
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    pn_type,
    text,
    text,
    boolean
    )
    RETURNS internal
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_sfunc'
    LANGUAGE C
    IMMUTABLE
    COST 100;

CREATE OR REPLACE FUNCTION cun_agg_finalfunc (internal)
    RETURNS text[]
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_finalfunc'
    LANGUAGE C
    STRICT 
    IMMUTABLE
    COST 100;

CREATE AGGREGATE cun_agg (
    text, 
    text,
    sign_variant_type, 
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    pn_type,
    text,
    text,
    boolean
    ) (
    SFUNC = cun_agg_sfunc,
    STYPE = internal,
    FINALFUNC = cun_agg_finalfunc
);

CREATE OR REPLACE FUNCTION cun_agg_html_sfunc (
    internal, 
    text, 
    text,
    sign_variant_type,  
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    pn_type,
    text,
    text,
    boolean
    )
    RETURNS internal
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_html_sfunc'
    LANGUAGE C
    IMMUTABLE
    COST 10000;

CREATE OR REPLACE FUNCTION cun_agg_html_finalfunc (internal)
    RETURNS text[]
    AS 'cuneiform_composer'
,
    'cuneiform_cun_agg_html_finalfunc'
    LANGUAGE C
    STRICT 
    IMMUTABLE
    COST 100;

CREATE AGGREGATE cun_agg_html (
    text, 
    text,
    sign_variant_type, 
    integer, 
    integer, 
    integer, 
    integer, 
    integer,
    sign_properties, 
    boolean, 
    sign_condition, 
    language, 
    boolean, 
    boolean, 
    boolean,
    text, 
    text,
    boolean,
    pn_type,
    text,
    text,
    boolean
    ) (
    SFUNC = cun_agg_html_sfunc,
    STYPE = internal,
    FINALFUNC = cun_agg_html_finalfunc
);


CREATE OR REPLACE FUNCTION compose_sign_html (
    tree jsonb)
    RETURNS TEXT
    LANGUAGE 'plpython3u' 
    COST 100
    IMMUTABLE
    STRICT
    TRANSFORM FOR TYPE jsonb
AS $BODY$
    import re

    precedence = {'.': 0, '×': 1, '&': 2, '%': 3, '@': 3, '+': 4}
    modifiers = {'g': 'gunû', 'š': 'šeššig', 't': 'tenû', 'n': 'nutillû', 'k': 'kabatenû', 'z': 'zidatenû', 'i': 'inversum', 'v': 'inversum', 'c': 'rounded'}

    def stack(a, b):
        return f'<span class="stack">{a}<br/>{b}</span>'
    
    def rotate(a, val):
        return f'<span class="rot{val}">{a}</span>'

    def compose(node):
        op = node['op']
        if len(node['vals']) == 2:
            if op == '&':
                return stack(compose(node['vals'][0]), compose(node['vals'][1]))
            elif op == '%':
                return '<span class="cross">'+stack(compose(node['vals'][0]), compose(node['vals'][1]))+'</span>'
            elif op == '@':
                return stack(rotate(compose(node['vals'][0]), '180'), compose(node['vals'][1]))
            return parenthesize(node['vals'][0], precedence[op], True) + op + parenthesize(node['vals'][1], precedence[op], False)
        elif len(node['vals']) == 1:
            if op in ['45', '90', '180']:
                return rotate(compose(node['vals'][0]), op)
            return parenthesize(node['vals'][0], 100, True) + '<span class="modifier">'+modifiers[op]+'</span>'
        else:
            if re.fullmatch(r'(BAU|LAK|KWU|RSP|REC|ZATU|ELLES)[0-9]{3}', op):
                return re.sub(r'([0-9]+)$', r'<span class="slindex">\1</span>', op)
            else:
                return re.sub(r'(?<=[^0-9x])([0-9x]+)$', r'<span class="index">\1</span>', op)

    def parenthesize(node, prec, left):
        if len(node['vals']) == 2 and precedence[node['op']] + int(left) <= prec and node['op'] in ['.', '×']:
            return '(' + compose(node) + ')'
        return compose(node)

    return compose(tree)
$BODY$;


CREATE TABLE value_variants_composed (
    value_variant_id integer PRIMARY KEY,
    value_id integer,
    main boolean,
    value_code text,
    value_html text
);

CREATE TABLE sign_variants_composed (
    sign_variant_id integer PRIMARY KEY,
    sign_code text,
    graphemes_code text,
    glyphs_code text,
    sign_html text,
    graphemes_html text,
    glyphs_html text,
    variant_type sign_variant_type
);

CREATE VIEW values_composed AS
SELECT
    value_id,
    value_code,
    value_html
FROM
    value_variants_composed
WHERE
    main;


CREATE VIEW value_variants_composed_view AS
SELECT
    value_variant_id,
    value_id,
    value_variant_id = main_variant_id,
    value,
    regexp_replace(value, '(?<=[^0-9x])([0-9x]+)$', '<span class=''index''>\1</span>')
FROM
    value_variants
    LEFT JOIN values USING (value_id);

INSERT INTO value_variants_composed SELECT * from value_variants_composed_view;


CREATE FUNCTION value_variants_composed_value_variants_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM value_variants_composed WHERE value_variants_composed.value_variant_id = (OLD).value_variant_id;
    ELSE
        INSERT INTO value_variants_composed
        SELECT
            *
        FROM
            value_variants_composed_view
        WHERE
            value_variant_id = (NEW).value_variant_id
        ON CONFLICT (value_variant_id) DO UPDATE SET
            value_id = EXCLUDED.value_id,
            main = EXCLUDED.main,
            value_code = EXCLUDED.value_code,
            value_html = EXCLUDED.value_html;
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE OR REPLACE FUNCTION value_variants_composed_values_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    UPDATE value_variants_composed SET main = value_variant_id = (NEW).main_variant_id WHERE value_id = (NEW).value_id;
    RETURN NULL;
END;
$BODY$;

CREATE TRIGGER value_variants_composed_value_variants_trigger
  AFTER UPDATE OR INSERT OR DELETE ON value_variants 
  FOR EACH ROW
  EXECUTE FUNCTION value_variants_composed_value_variants_trigger_fun();

CREATE TRIGGER value_variants_composed_values_trigger
  AFTER UPDATE ON values 
  FOR EACH ROW
  EXECUTE FUNCTION value_variants_composed_values_trigger_fun();



CREATE VIEW sign_variants_composed_view AS
SELECT
    sign_variant_id,
    string_agg(CASE WHEN allographs.variant_type = 'default' THEN grapheme ELSE glyph END, '.' ORDER BY ord) AS sign_code,
    string_agg(grapheme, '.'ORDER BY ord) AS graphemes_code,
    string_agg(glyph, '.' ORDER BY ord) AS glyphs_code,
    string_agg(CASE WHEN allographs.variant_type = 'default' THEN grapheme_html ELSE glyph_html END, '.' ORDER BY ord) AS sign_html,
    string_agg(grapheme_html, '.'ORDER BY ord) AS graphemes_html,
    string_agg(glyph_html, '.' ORDER BY ord) AS glyphs_html,
    sign_variants.variant_type
FROM
    sign_variants
    LEFT JOIN LATERAL unnest(allograph_ids) WITH ORDINALITY AS a(allograph_id, ord) ON TRUE
    LEFT JOIN allographs USING (allograph_id)
    LEFT JOIN graphemes USING (grapheme_id)
    LEFT JOIN glyphs USING (glyph_id)
    LEFT JOIN LATERAL compose_sign_html(parse_sign(grapheme)) AS b(grapheme_html) ON TRUE
    LEFT JOIN LATERAL compose_sign_html(parse_sign(glyph)) AS c(glyph_html) ON TRUE
GROUP BY
    sign_variant_id;

INSERT INTO sign_variants_composed SELECT * from sign_variants_composed_view;


CREATE OR REPLACE FUNCTION update_sign_variants_composed (
        v_sign_variant_id integer
    ) 
    RETURNS void 
    VOLATILE
    LANGUAGE PLPGSQL
    AS
$BODY$
BEGIN
    INSERT INTO sign_variants_composed 
    SELECT
        *
    FROM 
        sign_variants_composed_view
    WHERE
        sign_variant_id = v_sign_variant_id
    ON CONFLICT (sign_variant_id) DO UPDATE SET
        sign_code = EXCLUDED.sign_code,
        graphemes_code = EXCLUDED.graphemes_code,
        glyphs_code = EXCLUDED.glyphs_code,
        sign_html = EXCLUDED.sign_html,
        graphemes_html = EXCLUDED.graphemes_html,
        glyphs_html = EXCLUDED.glyphs_html,
        variant_type = EXCLUDED.variant_type;
END;
$BODY$;

CREATE FUNCTION sign_variants_composed_sign_variants_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    IF NEW IS NULL THEN
        DELETE FROM sign_variants_composed WHERE sign_variants_composed.sign_variant_id = (OLD).sign_variant_id;
    ELSE
        PERFORM update_sign_variants_composed((NEW).sign_variant_id);
    END IF;
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION sign_variants_composed_allographs_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    PERFORM 
        update_sign_variants_composed(sign_variant_id)
    FROM
        sign_variants 
    WHERE
        (NEW).allograph_id = ANY(allograph_ids);
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION sign_variants_composed_graphemes_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    PERFORM 
        update_sign_variants_composed(sign_variant_id)
    FROM
        sign_variants_composition 
    WHERE
        (NEW).grapheme_id = ANY(grapheme_ids);
    RETURN NULL;
END;
$BODY$;

CREATE FUNCTION sign_variants_composed_glyphs_trigger_fun () 
  RETURNS trigger 
  VOLATILE
  LANGUAGE PLPGSQL
  AS
$BODY$
BEGIN
    PERFORM 
        update_sign_variants_composed(sign_variant_id)
    FROM
        sign_variants_composition 
    WHERE
        (NEW).glyph_id = ANY(glyph_ids);
    RETURN NULL;
END;
$BODY$;

CREATE TRIGGER sign_variants_composed_sign_variants_trigger
  AFTER UPDATE OR INSERT OR DELETE ON sign_variants 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_sign_variants_trigger_fun();

CREATE TRIGGER sign_variants_composed_allographs_trigger
  AFTER UPDATE OF variant_type ON allographs 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_allographs_trigger_fun();

CREATE TRIGGER sign_variants_composed_graphemes_trigger
  AFTER UPDATE OF grapheme ON graphemes 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_graphemes_trigger_fun();

CREATE TRIGGER sign_variants_composed_glyphs_trigger
  AFTER UPDATE OF glyph ON glyphs 
  FOR EACH ROW
  EXECUTE FUNCTION sign_variants_composed_glyphs_trigger_fun();


CREATE OR REPLACE FUNCTION placeholder (type SIGN_TYPE)
    RETURNS text
    STRICT
    IMMUTABLE
    LANGUAGE SQL
AS $BODY$
    SELECT
        '<span class="placeholder">' 
        ||
        CASE type
        WHEN 'number' THEN
            'N'
        WHEN 'description' THEN
            'DESC'
        WHEN 'punctuation' THEN
            '|'
        WHEN 'damage' THEN
            '…'
        ELSE
            'X'
        END 
        ||
        '</span>'
$BODY$;


CREATE VIEW corpus_code AS
SELECT
    transliteration_id,
    CASE WHEN (properties).type = 'sign' THEN COALESCE(graphemes_code, custom_value) ELSE COALESCE(value_code, custom_value) END AS value,
    glyphs_code AS sign, 
    variant_type,
    sign_no, 
    word_no, 
    compound_no, 
    section_no,
    line_no, 
    properties, 
    stem, 
    condition, 
    language, 
    inverted, 
    newline,
    ligature,
    crits, 
    comment,
    capitalized,
    pn_type,
    section_name,
    compound_comment
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sections USING (transliteration_id, section_no)
    LEFT JOIN sign_variants_composed USING (sign_variant_id)
    LEFT JOIN values_composed USING (value_id);


CREATE VIEW corpus_code_clean AS
SELECT
    transliteration_id,
    CASE WHEN (properties).type = 'sign' THEN graphemes_code ELSE COALESCE(value_code, placeholder((properties).type)) END AS value,
    sign_code AS sign, 
    variant_type, 
    sign_no, 
    word_no, 
    compound_no, 
    properties, 
    stem,
    language
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sign_variants_composed USING (sign_variant_id)
    LEFT JOIN values_composed USING (value_id);


CREATE OR REPLACE VIEW corpus_html AS
SELECT
    transliteration_id,
    CASE WHEN (properties).type = 'sign' THEN COALESCE(graphemes_html,custom_value) ELSE COALESCE(value_html, custom_value) END AS value,
    glyphs_html AS sign,
    variant_type, 
    sign_no, 
    word_no, 
    compound_no, 
    section_no,
    line_no, 
    properties, 
    stem, 
    condition, 
    language, 
    inverted, 
    newline,
    ligature,
    crits, 
    comment, 
    capitalized,
    pn_type,
    section_name,
    compound_comment
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sections USING (transliteration_id, section_no)
    LEFT JOIN sign_variants_composed USING (sign_variant_id)
    LEFT JOIN values_composed USING (value_id);

CREATE VIEW corpus_html_clean AS
SELECT
    transliteration_id,
    CASE WHEN (properties).type = 'sign' THEN graphemes_html ELSE COALESCE(value_html, placeholder((properties).type)) END AS value,
    sign_html AS sign,
    variant_type, 
    sign_no, 
    word_no, 
    compound_no, 
    properties, 
    stem,
    language
FROM
    corpus
    LEFT JOIN words USING (transliteration_id, word_no) 
    LEFT JOIN compounds USING (transliteration_id, compound_no) 
    LEFT JOIN sign_variants_composed USING (sign_variant_id)
    LEFT JOIN values_composed USING (value_id);


CREATE VIEW corpus_code_range AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (value, sign, variant_type, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS content
FROM (
    SELECT
        a.transliteration_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus_code ON a.transliteration_id = corpus_code.transliteration_id
    AND RANGE @> corpus_code.sign_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_html_range AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg_html (value, sign, variant_type, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no)  AS content
FROM (
    SELECT
        a.transliteration_id,
        int4range(a.sign_no, b.sign_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.sign_no <= b.sign_no) a
JOIN corpus_html ON a.transliteration_id = corpus_html.transliteration_id
    AND RANGE @> corpus_html.sign_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE VIEW corpus_code_lines AS
SELECT
    a.transliteration_id,
    RANGE,
    cun_agg (value, sign, variant_type, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS content
FROM (
    SELECT DISTINCT
        a.transliteration_id,
        int4range(a.line_no, b.line_no, '[]') AS RANGE
    FROM
        corpus a
        JOIN corpus b ON a.transliteration_id = b.transliteration_id
            AND a.line_no <= b.line_no) a
JOIN corpus_code ON a.transliteration_id = corpus_code.transliteration_id
    AND RANGE @> corpus_code.line_no
GROUP BY
    a.transliteration_id,
    RANGE;

CREATE OR REPLACE VIEW corpus_code_transliterations AS
WITH a AS (
SELECT
    transliteration_id,
    cun_agg (value, sign, variant_type, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, newline, ligature, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus_code
GROUP BY
    transliteration_id
),
b AS (
SELECT
    a.transliteration_id,
    block_no,
    string_agg(line || E'\t' || content || COALESCE(E'\n# '|| line_comment, ''), E'\n' ORDER BY line_no) AS content
FROM
    a
    LEFT JOIN LATERAL UNNEST(lines) WITH ORDINALITY AS content(content, line_no_plus_one) ON TRUE
    LEFT JOIN lines ON a.transliteration_id = lines.transliteration_id AND line_no_plus_one = line_no + 1
GROUP BY
    a.transliteration_id,
    block_no
),
c AS (
SELECT
    transliteration_id,
    surface_no,
    string_agg(
        CASE 
            WHEN block_type != 'block' OR block_data IS NOT NULL THEN
                '@' || block_type::text || COALESCE(' '||block_data, '') || COALESCE(E'\n# '|| block_comment, '') || E'\n'
            ELSE
                ''
        END
        || content,
        E'\n' 
        ORDER BY block_no
    ) AS content
FROM
    b
    LEFT JOIN blocks USING (transliteration_id, block_no)
GROUP BY
    transliteration_id,
    surface_no
),
d AS (
SELECT
    transliteration_id,
    object_no,
    string_agg(
        CASE 
            WHEN surface_type != 'surface' OR surface_data IS NOT NULL THEN
                '@' || surface_type::text || COALESCE(' '||surface_data, '') || COALESCE(E'\n# '|| surface_comment, '') || E'\n' 
            ELSE
                ''
        END 
        || content, 
        E'\n' 
        ORDER BY surface_no
    ) AS content
FROM
    c
    LEFT JOIN surfaces USING (transliteration_id, surface_no)
GROUP BY
    transliteration_id,
    object_no
)
SELECT
    transliteration_id,
    string_agg(
        CASE 
            WHEN object_type != 'object' OR object_data IS NOT NULL THEN
                '@' || object_type::text || COALESCE(' '||object_data, '') || COALESCE(E'\n# '|| object_comment, '') || E'\n' 
            ELSE
                ''
        END
        || content, 
        E'\n' 
        ORDER BY object_no
    ) AS content
FROM
    d
    LEFT JOIN objects USING (transliteration_id, object_no)
GROUP BY
    transliteration_id;


CREATE VIEW corpus_html_transliterations AS
WITH a AS (
SELECT
    transliteration_id,
    cun_agg_html (value, sign, variant_type, sign_no, word_no, compound_no, section_no, line_no, properties, stem, condition, language, 
        inverted, ligature, newline, crits, comment, capitalized, pn_type, section_name, compound_comment, FALSE ORDER BY sign_no) AS lines
FROM corpus_html
GROUP BY
    transliteration_id
)
SELECT transliteration_id, line_no-1 AS line_no, line FROM a, LATERAL UNNEST(lines) WITH ORDINALITY AS content(line, line_no);