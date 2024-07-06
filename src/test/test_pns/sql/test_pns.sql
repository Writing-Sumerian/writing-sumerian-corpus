CREATE OR REPLACE FUNCTION test_pns_basic ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\ti3-ni', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 0, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('a-ni', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\ti3-ni') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('ni-ni', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tni-ni') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('i3', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tni-ni') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('a-ni-e', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tni-ni') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;


CREATE OR REPLACE FUNCTION test_replace_composites ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tensi2-a-diri', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 0, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('PA.TE-diri-si-A', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tPA.TE-diri-si-A') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;


CREATE OR REPLACE FUNCTION test_replace_inversion ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi:a', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 0, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('diri', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tsi:a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('sig9-a', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tsig9:a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_ligature ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi+a', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 0, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('diri', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tsi+a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('sig9-a', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tsig9+a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_word ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\te-si--&a', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 0, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('e-diri', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\te-diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('e-si--&a', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\te-si--&a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_conditions ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\t⸢ensi2⸣-‹a›-«diri»', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 0, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('pa-te-si-A.SI.A', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\t⸢pa-te-si⸣-‹A›.«SI.A»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('pa-te-diri-SI.A', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\t⸢pa-te-si⸣-‹A›.«SI.A»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('ensi2-A.SI.A', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\t⸢ensi2⸣-‹A›.«SI.A»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_multiword ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\ta i3-ni a', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 1, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('ni-ni', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\ta ni-ni a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_newline ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\ta si-/a', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 1, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('diri', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\ta / diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_multiline ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi-\n2\ta a', -1, '@extschema:cuneiform_corpus@');
INSERT INTO @extschema:cuneiform_corpus_pns@.compounds_pns VALUES (-1, 0, -1, 0);
CALL @extschema:cuneiform_pns@.edit_pn_variant('diri', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tsi-\n2\ta a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
UPDATE @extschema:cuneiform_corpus_pns@.compounds_pns SET compound_no = 1 WHERE transliteration_id = -1;
CALL @extschema:cuneiform_pns@.edit_pn_variant('A', -1, 0);
CALL @extschema:cuneiform_corpus_pns@.adjust_pn_in_corpus(-1, -1, true);
RETURN NEXT is(content, E'1\tsi-\n2\ta A') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;