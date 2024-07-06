CREATE OR REPLACE FUNCTION test_replace_basic ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\ti3 ni', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('i3', 'a',-1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 ni') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('i3', 'ni', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni ni') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('NI', 'i3', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 i3') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('NI NI', 'i3 NI', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 NI') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('NI NI', 'i3', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 NI') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('NI NI', 'i3 NI e', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 NI') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_basic_references ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\ti3 ni', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('(NI) (NI)', '"2" "1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni i3') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(NI NI)', 'i3 "1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni i3') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(NI) (NI)', '"2"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni i3') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(NI) (NI)', '"2" "2"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 i3') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_composites ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tensi2 a diri', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'si-a', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tensi2 a si-a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tensi2 a diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('ENSI2 a', 'PA.TE diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tPA.TE diri diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;


CREATE OR REPLACE FUNCTION test_replace_overlap ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\ta a a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('A A', 'ayya', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ta a a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(A) A A', '"1" aya', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ta aya') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;


CREATE OR REPLACE FUNCTION test_replace_composite_references ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tdiri si-a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) … (DIRI)', '"2"-"1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a-diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) … (DIRI)', 'si a si', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a-diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) … (DIRI)', 'si a si a si', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a-diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) … (DIRI)', 'si a si a', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a si a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_gap ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tdiri e si-a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) … (DIRI)', '"2"-"1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tdiri e si-a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) … (DIRI)', '"2"--"1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tdiri e si-a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) … (DIRI)', '"2" "1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a e diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
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
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi:a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('si', 'sig9', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
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
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi+a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('si', 'sig9', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
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
CALL @extschema:cuneiform_parser@.parse(E'1\te-si &a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te-diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'si &a', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te-si &a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_word_reference ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi-a-si a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) (DIRI)', '"2" "1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a si-a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_1 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\te--si %person &a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'si %person &a', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--si %person &a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_2 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\te--si %a a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--diri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'si %a a', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--si %a a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_reference ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi--a--si a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('(DIRI) (DIRI)', '"2" "1"', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a si--a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_comment_1 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi (?) a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi (?) a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_comment_2 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi a (?)', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a (?)') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_capitalization ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi &a', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('DIRI', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tdiri') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('diri', 'si &a', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi &a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_multiple ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tdiri diri', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('diri', 'si-a', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a si-a') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
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
CALL @extschema:cuneiform_replace_corpus@.replace('ensi2', 'pa-te-si', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\t⸢pa-te-si⸣-‹a›-«diri»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('a', 'A', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\t⸢pa-te-si⸣-‹A›-«diri»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('diri', 'SI.A', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\t⸢pa-te-si⸣-‹A›.«SI.A»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('si-A', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\t⸢pa-te-si⸣-‹A›.«SI.A»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
CALL @extschema:cuneiform_replace_corpus@.replace('pa-te-si', 'ensi2', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\t⸢ensi2⸣-‹A›.«SI.A»') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_multiline ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL @extschema:cuneiform_parser@.parse(E'1\tsi\n2\ta', -1, '@extschema:cuneiform_corpus@');
CALL @extschema:cuneiform_replace_corpus@.replace('SI A', 'diri', -1, true, false, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi\n2\ta') FROM @extschema:cuneiform_serialize_corpus@.transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;