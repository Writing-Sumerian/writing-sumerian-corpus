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

CREATE TYPE indicator_type AS ENUM (
    'none',
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

CREATE TYPE pn_type AS ENUM (
    'none',
    'person', 
    'god',
    'place',   
    'water', 
    'field', 
    'temple', 
    'month',
    'object',
    'ethnicity'
);
