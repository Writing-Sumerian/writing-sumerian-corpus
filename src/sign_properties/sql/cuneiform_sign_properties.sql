CREATE TYPE language AS ENUM (
    'sumerian',
    'akkadian',
    'hittite',
    'eblaite',
    'other'
);

CREATE TYPE sign_type AS ENUM (
    'value',
    'sign',
    'number',
    'punctuation',
    'description',
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
    'deleted',
    'erased'
);

CREATE TYPE sign_properties AS (
    TYPE SIGN_TYPE,
    indicator boolean,
    alignment ALIGNMENT,
    phonographic boolean
);

CREATE TYPE pn_type AS ENUM (
    'person', 
    'god',
    'place',   
    'water', 
    'field', 
    'temple', 
    'month',
    'object'
);
