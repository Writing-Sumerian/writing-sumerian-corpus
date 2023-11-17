CREATE OR REPLACE FUNCTION test_replace_basic ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\ti3 ni', 'public', 'sumerian', false, -1);
CALL replace('i3','a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 ni') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('i3','ni','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni ni') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('NI','i3','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 i3') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('NI NI','i3 NI','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 NI') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('NI NI','i3','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 NI') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('NI NI','i3 NI e','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 NI') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_basic_references ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\ti3 ni', 'public', 'sumerian', false, -1);
CALL replace('(NI) (NI)','"2" "1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni i3') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(NI NI)','i3 "1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni i3') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(NI) (NI)','"2"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tni i3') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(NI) (NI)','"2" "2"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ti3 i3') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_composites ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tensi2 a diri', 'public', 'sumerian', false, -1);
CALL replace('DIRI','si-a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tensi2 a si-a') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tensi2 a diri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('ENSI2 a','PA.TE diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tPA.TE diri diri') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;


CREATE OR REPLACE FUNCTION test_replace_overlap ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\ta a a', 'public', 'sumerian', false, -1);
CALL replace('A A','ayya','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ta a a') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(A) A A','"1" aya','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\ta aya') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;


CREATE OR REPLACE FUNCTION test_replace_composite_references ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tdiri si-a', 'public', 'sumerian', false, -1);
CALL replace('(DIRI) … (DIRI)','"2"-"1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a-diri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(DIRI) … (DIRI)','si a si','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a-diri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(DIRI) … (DIRI)','si a si a si','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a-diri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(DIRI) … (DIRI)','si a si a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a si a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_gap ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tdiri e si-a', 'public', 'sumerian', false, -1);
CALL replace('(DIRI) … (DIRI)','"2"-"1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tdiri e si-a') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(DIRI) … (DIRI)','"2"--"1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tdiri e si-a') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('(DIRI) … (DIRI)','"2" "1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a e diri') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_ligature ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi+a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi+a') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('si','sig9','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsig9+a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_inversion ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi:a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi:a') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('si','sig9','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsig9:a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_ligature ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi+a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi+a') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('si','sig9','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsig9+a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_word ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\te-si &a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te-diri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('DIRI','si &a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te-si &a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_word_reference ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi-a-si a', 'public', 'sumerian', false, -1);
CALL replace('(DIRI) (DIRI)','"2" "1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a si-a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_1 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\te--si %person &a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--diri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('DIRI','si %person &a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--si %person &a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_2 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\te--si %a a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--diri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('DIRI','si %a a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\te--si %a a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_reference ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi--a--si a', 'public', 'sumerian', false, -1);
CALL replace('(DIRI) (DIRI)','"2" "1"','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a si--a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_comment_1 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi (?) a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi (?) a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_compound_comment_2 ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi a (?)', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi a (?)') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_capitalization ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tsi &a', 'public', 'sumerian', false, -1);
CALL replace('DIRI','diri','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tdiri') FROM transliterations_serialized WHERE transliteration_id = -1;
CALL replace('diri','si &a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi &a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;

CREATE OR REPLACE FUNCTION test_replace_multiple ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'1\tdiri diri', 'public', 'sumerian', false, -1);
CALL replace('diri','si-a','sumerian', false, -1, true, ARRAY[]::integer[], ARRAY[]::integer[], ARRAY[-1]);
RETURN NEXT is(content, E'1\tsi-a si-a') FROM transliterations_serialized WHERE transliteration_id = -1;
END;
$BODY$;