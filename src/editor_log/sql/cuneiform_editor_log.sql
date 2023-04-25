CREATE TABLE edits (
    edit_id BIGSERIAL PRIMARY KEY,
    transliteration_id integer REFERENCES transliterations(transliteration_id) ON DELETE CASCADE,
    timestamp timestamp,
    user_id text,
    internal boolean
);

CREATE TABLE edit_log (
    edit_id integer REFERENCES edits (edit_id) ON DELETE CASCADE,
    log_no integer,
    entry_no integer,
    target text,
    action text,
    query text,
    PRIMARY KEY (edit_id, log_no)
);