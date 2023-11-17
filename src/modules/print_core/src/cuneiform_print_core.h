#ifndef CUNEIFORM_COMPOSER_CORE_H
#define CUNEIFORM_COMPOSER_CORE_H

#include <postgres.h>
#include <fmgr.h>

typedef struct CunEnumType {
    Oid value;
    Oid sign;
    Oid number;
    Oid punctuation;
    Oid description;
    Oid damage;
} cunEnumType;

typedef struct CunEnumIndicatorType {
    Oid none;
    Oid left;
    Oid right;
    Oid center;
} cunEnumIndicatorType;


typedef struct CunEnumLanguage {
    Oid sumerian;
    Oid akkadian;
    Oid hittite;
    Oid eblaite;
    Oid other;
} cunEnumLanguage;

typedef struct CunEnumCondition {
    Oid intact;
    Oid damaged;
    Oid lost;
    Oid inserted;
    Oid deleted;
    Oid erased;
} cunEnumCondition;

typedef struct CunEnumVariantType {
    Oid default_variant;
    Oid nondefault;
    Oid reduced;
    Oid augmented;
    Oid nonstandard;
} cunEnumVariantType;

typedef struct CunEnumPN {
    Oid person;
    Oid god;
    Oid place;
    Oid water;
    Oid field;
    Oid temple;
    Oid month;
    Oid object;
    Oid ethnicity;
} cunEnumPN;

typedef void (*set_enums_t) (
    cunEnumType *type,
    cunEnumIndicatorType *indicator_type,
    cunEnumLanguage *language,
    cunEnumCondition *condition,
    cunEnumVariantType *variant_type,
    cunEnumPN *pn,
    bool *enums_set
);


#define  LANGUAGE          128
#define  PN_TYPE            64
#define  STEM               32
#define  HIGHLIGHT          16
#define  PHONOGRAPHIC        8
#define  TYPE                4
#define  INDICATOR           2
#define  CONDITION           1

#define ARG_VALUE                1
#define ARG_SIGN                 2
#define ARG_SIGN_NO              3
#define ARG_WORD_NO              4
#define ARG_COMPOUND_NO          5
#define ARG_SECTION_NO           6
#define ARG_LINE_NO              7
#define ARG_TYPE                 8
#define ARG_INDICATOR_TYPE       9
#define ARG_PHONOGRAPHIC        10      
#define ARG_STEM                11
#define ARG_CONDITION           12
#define ARG_LANGUAGE            13
#define ARG_INVERTED            14
#define ARG_NEWLINE             15
#define ARG_LIGATURE            16
#define ARG_CRITICS             17
#define ARG_COMMENT             18
#define ARG_CAPITALIZED         19
#define ARG_PN_TYPE             20
#define ARG_SECTION             21
#define ARG_COMPOUND_COMMENT    22
#define ARG_HIGHLIGHT           23

typedef struct State
{
    Datum* lines;
    int32 line_count;
    text* string;
    size_t string_capacity;

    text* compound_comment;
    size_t compound_comment_capacity;

    int32 sign_no;
    int32 word_no;
    int32 compound_no;
    int32 line_no;
    int32 section_no;
    bool section_null;
    Oid type;
    bool phonographic;
    Oid indicator_type;
    bool stem;
    Oid condition;
    Oid language;
    bool unknown_reading;
    bool stem_null;
    bool phonographic_null;
    Oid pn_type;
    bool pn_type_null;
    bool highlight;

    bool capitalize;
} State;


#define SEP_DASH            0
#define SEP_DOT             1
#define SEP_NUMBER          2
#define SEP_INDICATOR_P     3
#define SEP_INDICATOR_L     4
#define SEP_INDICATOR_M     5
#define SEP_INDICATOR_0     6
#define SEP_WORD            7
#define SEP_COMPOUND        8

#define SEP_EXT_NEWLINE     1
#define SEP_EXT_LINEBREAK   2
#define SEP_EXT_LIGATURE    3
#define SEP_EXT_INVERSION   4

typedef struct Connector
{
    int connector;
    int modifier;
    bool ellipsis;
} Connector;

extern PGDLLEXPORT void set_enums();
extern PGDLLEXPORT cunEnumType *cun_enum_type();
extern PGDLLEXPORT cunEnumIndicatorType *cun_enum_indicator_type();
extern PGDLLEXPORT cunEnumLanguage *cun_enum_language();
extern PGDLLEXPORT cunEnumCondition *cun_enum_condition();
extern PGDLLEXPORT cunEnumVariantType *cun_enum_variant_type();
extern PGDLLEXPORT cunEnumPN *cun_enum_pn();

extern PGDLLEXPORT char* cun_memcpy(char* s1, const char* s2, size_t n);
extern PGDLLEXPORT char* cun_strcpy(char* s1, const char* s2);
extern PGDLLEXPORT int cun_strcmp(const char* s1, const char* s2);
extern PGDLLEXPORT void cun_capitalize(char* s);
extern PGDLLEXPORT bool cun_has_char(const char* s, char c, size_t n);

extern State* cun_init_state(FunctionCallInfo fcinfo, MemoryContext memcontext, State* state_old);
extern int cun_get_changes(const State* s1, const State* s2);

extern Connector cun_determine_connector(const State* s1, const State* s2, bool inverted, bool newline, bool ligature);
extern Oid cun_opened_condition_start(const char* s, size_t n, bool* no_condition);
extern Oid cun_opened_condition_end(const char* s, size_t n);

#endif // CUNEIFORM_COMPOSER_CORE_H