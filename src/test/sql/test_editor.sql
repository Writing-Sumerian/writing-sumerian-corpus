CREATE OR REPLACE FUNCTION test_editor ()
    RETURNS SETOF text
    VOLATILE
    LANGUAGE PLPGSQL
    AS 
$BODY$
BEGIN
CALL parse(E'@object pot\n@obverse\n@column 1\n1\ta %sec=a [&a--a!]-/a (a?) 5+6 %person {d}«A»⸢<a>⸣--\n2\t‹&a› a:A &|A.A|;-a+a', 'public', 'sumerian', false, -1);
CALL edit_transliteration(E'@surface C\n@block b\n3\t<e?>E--&e+E\n# blah\n@object pot\n1\t[e]-;|E|-e %sec=b e:‹e›{ki}', -1, 'sumerian', false, -1);
RETURN NEXT is(content, E'@surface C\n@block b\n3\t<e?>E--&e+E\n# blah\n@object pot\n1\t[e]-;E-e %sec=b e:‹e›{ki}') FROM corpus_code_transliterations WHERE transliteration_id = -1;
CALL undo(-1, '-infinity', 'public');
RETURN NEXT is(content, E'@object pot\n@obverse\n@column 1\n1\ta %sec=a [&a--a!]-/a (a?) 5+6 %person &{d}«A»⸢<a>⸣--\n2\t‹&a› a:A &|A.A|;-a+a') FROM corpus_code_transliterations WHERE transliteration_id = -1;
END;
$BODY$;