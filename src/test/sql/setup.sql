
CREATE OR REPLACE FUNCTION startup ()
    RETURNS void
    VOLATILE
    LANGUAGE SQL
    AS 
$BODY$
INSERT INTO corpora VALUES (-1, 'test', 'test', false);
INSERT INTO genres VALUES (-1, 'test');
INSERT INTO texts_norm VALUES (-1, null, null, 'test', null, null, null, null, -1, null, null, null);
INSERT INTO transliterations VALUES (-1, -1, -1);
INSERT INTO compositions (VALUES (-1, 'a'), (-2, 'b'));
$BODY$;


CREATE OR REPLACE FUNCTION shutdown ()
    RETURNS void
    VOLATILE
    LANGUAGE SQL
    AS 
$BODY$
DELETE FROM transliterations WHERE transliteration_id = -1;
DELETE FROM texts_norm WHERE text_id = -1;
DELETE FROM genres WHERE genre_id = -1;
DELETE FROM corpora WHERE corpus_id = -1;
DELETE FROM compositions WHERE composition_id = -1 OR composition_id = -2;
$BODY$;