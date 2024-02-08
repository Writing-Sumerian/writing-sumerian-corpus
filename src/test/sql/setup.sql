
CREATE OR REPLACE FUNCTION startup ()
    RETURNS void
    VOLATILE
    LANGUAGE SQL
    AS 
$BODY$
INSERT INTO corpora VALUES (-1, 'test', 'test', false);
INSERT INTO genres VALUES (-1, 'test');
INSERT INTO ensembles VALUES (-1, 'test');
INSERT INTO texts VALUES (-1, -1, null, null, 'test', null, null, null, null, null, -1, null, null, null, null);
INSERT INTO transliterations VALUES (-1, -1, -1);
INSERT INTO compositions (VALUES (-1, 'a'), (-2, 'b'));
CREATE TABLE errors (
    transliteration_id integer,
    line integer,
    col integer,
    symbol text,
    message text
);
$BODY$;


CREATE OR REPLACE FUNCTION shutdown ()
    RETURNS void
    VOLATILE
    LANGUAGE SQL
    AS 
$BODY$
DELETE FROM transliterations WHERE transliteration_id = -1;
DELETE FROM texts WHERE text_id = -1;
DELETE FROM ensembles WHERE ensemble_id = -1;
DELETE FROM genres WHERE genre_id = -1;
DELETE FROM corpora WHERE corpus_id = -1;
DELETE FROM compositions WHERE composition_id = -1 OR composition_id = -2;
DROP TABLE errors;
$BODY$;