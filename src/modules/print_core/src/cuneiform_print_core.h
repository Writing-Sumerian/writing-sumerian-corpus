#ifndef CUNEIFORM_PRINT_CORE_H
#define CUNEIFORM_PRINT_CORE_H

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

typedef void (*cun_set_enums_t)();
typedef cunEnumType *(*cun_enum_type_t)();
typedef cunEnumIndicatorType *(*cun_enum_indicator_type_t)();
typedef cunEnumLanguage *(*cun_enum_language_t)();
typedef cunEnumCondition *(*cun_enum_condition_t)();
typedef cunEnumVariantType *(*cun_enum_variant_type_t)();
typedef cunEnumPN *(*cun_enum_pn_t)();
extern void cun_set_enums();
extern cunEnumType *cun_enum_type();
extern cunEnumIndicatorType *cun_enum_indicator_type();
extern cunEnumLanguage *cun_enum_language();
extern cunEnumCondition *cun_enum_condition();
extern cunEnumVariantType *cun_enum_variant_type();
extern cunEnumPN *cun_enum_pn();

typedef char *(*cun_copy_n_t)(char *s1, const char *s2, size_t n);
typedef char *(*cun_copy_t)(char *s1, const char *s2);
typedef int (*cun_compare_next_t)(const char *s1, const char *s2);
typedef void (*cun_capitalize_t)(char *s);
extern char *cun_copy_n(char *s1, const char *s2, size_t n);
extern char *cun_copy(char *s1, const char *s2);
extern int cun_compare_next(const char *s1, const char *s2);
extern void cun_capitalize(char *s);

typedef State *(*cun_init_state_t)(MemoryContext memcontext);
typedef int (*cun_get_changes_t)(const State *s1, const State *s2);
typedef Connector (*cun_determine_connector_t)(const State *s1, const State *s2, bool inverted, bool newline, bool ligature);
typedef Oid (*cun_opened_condition_start_t)(const char *s, size_t n, bool *no_condition);
typedef Oid (*cun_opened_condition_end_t)(const char *s, size_t n);
typedef void (*cun_copy_compound_comment_t)(const text *compound_comment, State *state);
extern State *cun_init_state(MemoryContext memcontext);
extern int cun_get_changes(const State *s1, const State *s2);
extern Connector cun_determine_connector(const State *s1, const State *s2, bool inverted, bool newline, bool ligature);
extern Oid cun_opened_condition_start(const char *s, size_t n, bool *no_condition);
extern Oid cun_opened_condition_end(const char *s, size_t n);
extern void cun_copy_compound_comment(const text *compound_comment, State *state);

#endif // CUNEIFORM_PRINT_CORE_H