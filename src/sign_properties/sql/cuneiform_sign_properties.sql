CREATE TYPE
LANGUAGE AS
ENUM (
    'sumerian',
    'akkadian',
    'other'
);

CREATE TYPE sign_type AS ENUM (
    'value',
    'sign',
    'number',
    'punctuation',
    'desc',
    'damage'
);

CREATE TYPE alignment AS ENUM (
    'left',
    'right',
    'center'
);

CREATE TYPE sign_condition AS ENUM (
    'intact',
    'damaged',
    'lost',
    'inserted',
    'deleted'
);

CREATE TYPE sign_properties AS (
    TYPE SIGN_TYPE,
    indicator boolean,
    alignment ALIGNMENT,
    phonographic boolean
);

