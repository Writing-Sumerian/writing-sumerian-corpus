#include "cuneiform_composer.h"

#include <math.h>

#include <fmgr.h>
#include <executor/executor.h>
#include <executor/spi.h>
#include <utils/builtins.h>
#include <access/htup_details.h>
#include <catalog/pg_type.h>
#include <utils/array.h>
#include <tcop/pquery.h>


#define  LANGUAGE          128
#define  PN_TYPE            64
#define  STEM               32
#define  HIGHLIGHT          16
#define  PHONOGRAPHIC        8
#define  TYPE                4
#define  INDICATOR           2
#define  CONDITION           1


#define EXP_LINE_SIZE_CODE  100
#define MAX_EXTRA_SIZE_CODE  50
#define EXP_LINE_SIZE_HTML 1000
#define MAX_EXTRA_SIZE_HTML 200


Oid TYPE_VALUE;
Oid TYPE_SIGN;
Oid TYPE_NUMBER;
Oid TYPE_PUNCTUATION;
Oid TYPE_DESCRIPTION;
Oid TYPE_DAMAGE;

Oid ALIGNMENT_LEFT;
Oid ALIGNMENT_RIGHT;
Oid ALIGNMENT_CENTER;

Oid LANGUAGE_SUMERIAN;
Oid LANGUAGE_AKKADIAN;
Oid LANGUAGE_HITTITE;
Oid LANGUAGE_EBLAITE;
Oid LANGUAGE_OTHER;

Oid CONDITION_INTACT;
Oid CONDITION_DAMAGED;
Oid CONDITION_LOST;
Oid CONDITION_INSERTED;
Oid CONDITION_DELETED;
Oid CONDITION_ERASED;

Oid VARIANT_TYPE_DEFAULT;
Oid VARIANT_TYPE_NONDEFAULT;
Oid VARIANT_TYPE_REDUCED;
Oid VARIANT_TYPE_AUGMENTED;
Oid VARIANT_TYPE_NONSTANDARD;

Oid PN_PERSON;
Oid PN_GOD;
Oid PN_PLACE;
Oid PN_WATER;
Oid PN_FIELD;
Oid PN_TEMPLE;
Oid PN_MONTH;
Oid PN_OBJECT;
Oid PN_ETHNICITY;

bool ENUMS_SET = false;


static void set_enums()
{
    if(ENUMS_SET)
        return;

    SPI_connect();

    SPI_execute("SELECT 'sumerian'::language, 'akkadian'::language, 'hittite'::language, 'eblaite'::language, 'other'::language", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        bool isnull;
        LANGUAGE_SUMERIAN = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        LANGUAGE_AKKADIAN = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        LANGUAGE_HITTITE = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        LANGUAGE_EBLAITE = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        LANGUAGE_OTHER = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
    }
    SPI_execute("SELECT 'left'::alignment, 'right'::alignment, 'center'::alignment", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        bool isnull;
        ALIGNMENT_LEFT = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        ALIGNMENT_RIGHT = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        ALIGNMENT_CENTER = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
    }
    SPI_execute("SELECT 'value'::sign_type, 'sign'::sign_type, 'number'::sign_type, 'punctuation'::sign_type,"
                "       'description'::sign_type, 'damage'::sign_type", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        bool isnull;
        TYPE_VALUE = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        TYPE_SIGN = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        TYPE_NUMBER = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        TYPE_PUNCTUATION = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        TYPE_DESCRIPTION = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
        TYPE_DAMAGE = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 6, &isnull));
    }
    SPI_execute("SELECT 'intact'::sign_condition, 'damaged'::sign_condition, 'lost'::sign_condition,"
                "       'inserted'::sign_condition, 'deleted'::sign_condition, 'erased'::sign_condition", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        bool isnull;
        CONDITION_INTACT = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        CONDITION_DAMAGED = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        CONDITION_LOST = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        CONDITION_INSERTED = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        CONDITION_DELETED = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
        CONDITION_ERASED = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 6, &isnull));
    }
    SPI_execute("SELECT 'default'::sign_variant_type, 'nondefault'::sign_variant_type, 'reduced'::sign_variant_type,"
                "       'augmented'::sign_variant_type, 'nonstandard'::sign_variant_type", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        bool isnull;
        VARIANT_TYPE_DEFAULT = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        VARIANT_TYPE_NONDEFAULT = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        VARIANT_TYPE_REDUCED = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        VARIANT_TYPE_AUGMENTED = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        VARIANT_TYPE_NONSTANDARD = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
    }
    SPI_execute("SELECT 'person'::pn_type, 'god'::pn_type, 'place'::pn_type, 'water'::pn_type, 'field'::pn_type,"
                "       'temple'::pn_type, 'month'::pn_type, 'object'::pn_type, 'ethnicity'::pn_type", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        bool isnull;
        PN_PERSON = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        PN_GOD = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        PN_PLACE = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        PN_WATER = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        PN_FIELD = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
        PN_TEMPLE = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 6, &isnull));
        PN_MONTH = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 7, &isnull));
        PN_OBJECT = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 8, &isnull));
        PN_ETHNICITY = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 9, &isnull));
    }
    
    SPI_finish();

    ENUMS_SET = true;
}


static char* cun_memcpy(char* s1, const char* s2, size_t n)
{
    while(n-- != 0)
        *s1++ = *s2++;
    return s1;
}

static char* cun_strcpy(char* s1, const char* s2)
{
    while(*s2 != '\0')
        *s1++ = *s2++;
    return s1;
}

static int cun_strcmp(const char* s1, const char* s2)
{
    while(*s2 != '\0')
    {
        if(*s1 < *s2)
            return -1;
        if(*s1++ > *s2++)
            return 1;
    }
    return 0;
}

static void cun_capitalize(char* s)
{
    if(*s & (1 << 8))
    {
        if(!cun_strcmp(s, "’"))
            cun_capitalize(s+strlen("’"));
        else if(!cun_strcmp(s, "ḫ"))
            cun_strcpy(s,"Ḫ");
        else if(!cun_strcmp(s, "š"))
            cun_strcpy(s,"Š");
        else if(!cun_strcmp(s, "ĝ"))
            cun_strcpy(s,"Ĝ");
        else if(!cun_strcmp(s, "ř"))
            cun_strcpy(s,"Ř");
        else if(!cun_strcmp(s, "ṣ"))
            cun_strcpy(s,"Ṣ");
        else if(!cun_strcmp(s, "ṭ"))
            cun_strcpy(s,"Ṭ");
    }
    else
        *s = toupper(*s);
}

static bool cun_has_char(const char* s, char c, size_t n)
{
    while(n-- != 0)
        if(s[n] == c)
            return true;
    return false;
}

#define ARG_VALUE                1
#define ARG_SIGN                 2
#define ARG_VARIANT_TYPE         3
#define ARG_SIGN_NO              4
#define ARG_WORD_NO              5
#define ARG_COMPOUND_NO          6
#define ARG_SECTION_NO           7
#define ARG_LINE_NO              8
#define ARG_PROPERITIES          9
#define ARG_STEM                10
#define ARG_CONDITION           11
#define ARG_LANGUAGE            12
#define ARG_INVERTED            13
#define ARG_NEWLINE             14
#define ARG_LIGATURE            15
#define ARG_CRITICS             16
#define ARG_COMMENT             17
#define ARG_CAPITALIZED         18
#define ARG_PN_TYPE             19
#define ARG_SECTION             20
#define ARG_COMPOUND_COMMENT    21
#define ARG_HIGHLIGHT           22

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
    bool indicator;
    Oid alignment;
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


static State* init_state(FunctionCallInfo fcinfo, MemoryContext memcontext, State* state_old)
{
    bool isnull;
    State* state;

    if(PG_ARGISNULL(0))
    {
        state = (State*) MemoryContextAllocZero(memcontext, sizeof(State));
        state->lines = (Datum*) MemoryContextAllocZero(memcontext, 0);
        state->line_count = 0;
        state->string = (text*) MemoryContextAllocZero(memcontext, VARHDRSZ + 1000);
        state->string_capacity = 1000;
        SET_VARSIZE(state->string, VARHDRSZ);
        state->compound_comment = (text*) MemoryContextAllocZero(memcontext, VARHDRSZ + 100);
        state->compound_comment_capacity = 100;
        SET_VARSIZE(state->compound_comment, VARHDRSZ);
        state->word_no = -1;
        state->capitalize = false;
    }
    else
        state = (State*) PG_GETARG_POINTER(0);

    *state_old = *state;

    state->sign_no = PG_GETARG_INT32(ARG_SIGN_NO);
    state->word_no = PG_GETARG_INT32(ARG_WORD_NO);
    state->compound_no = PG_GETARG_INT32(ARG_COMPOUND_NO);
    state->line_no = PG_GETARG_INT32(ARG_LINE_NO);
    state->section_no = PG_GETARG_INT32(ARG_SECTION_NO);
    state->section_null = PG_ARGISNULL(ARG_SECTION_NO);
    const HeapTupleHeader properties = PG_GETARG_HEAPTUPLEHEADER(ARG_PROPERITIES);
    state->type = DatumGetObjectId(GetAttributeByName(properties, "type", &isnull));
    state->phonographic = DatumGetBool(GetAttributeByName(properties, "phonographic", &state->phonographic_null));
    state->alignment = DatumGetObjectId(GetAttributeByName(properties, "alignment", &isnull));
    state->indicator = DatumGetBool(GetAttributeByName(properties, "indicator", &isnull));
    state->stem = PG_GETARG_BOOL(ARG_STEM);
    state->stem_null = PG_ARGISNULL(ARG_STEM);
    state->condition = PG_GETARG_OID(ARG_CONDITION);
    state->language = PG_GETARG_OID(ARG_LANGUAGE);
    state->pn_type = PG_GETARG_OID(ARG_PN_TYPE);
    state->pn_type_null = PG_ARGISNULL(ARG_PN_TYPE);
    state->highlight = PG_ARGISNULL(ARG_HIGHLIGHT) ? false : PG_GETARG_BOOL(ARG_HIGHLIGHT);

    state->capitalize = state_old->capitalize || (PG_GETARG_BOOL(ARG_CAPITALIZED) && state_old->word_no != state->word_no);

    state->unknown_reading = state->type == TYPE_SIGN;

    return state;
}


static int get_changes(const State* s1, const State* s2)
{
    int changes = 0;
    if(s1->condition != s2->condition)
        changes += CONDITION;
    if(s1->indicator != s2->indicator || s1->alignment != s2->alignment)
        changes += INDICATOR;
    if(s1->type != s2->type || s1->unknown_reading != s2->unknown_reading)
        changes += TYPE;
    if(s1->phonographic != s2->phonographic || s1->phonographic_null != s2->phonographic_null)
        changes += PHONOGRAPHIC;
    if(s1->highlight != s2->highlight)
        changes += HIGHLIGHT;
    if(s1->stem != s2->stem || s1->stem_null != s2->stem_null || (!s1->stem_null && s1->stem && s1->word_no != s2->word_no))
        changes += STEM;
    if(s1->pn_type != s2->pn_type || s1->pn_type_null != s2->pn_type_null || s1->word_no != s2->word_no)
        changes += PN_TYPE;
    if(s1->language != s2->language)
        changes += LANGUAGE;
    return changes;
}


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

static Connector determine_connector(const State* s1, const State* s2, bool inverted, bool newline, bool ligature)
{
    Connector res = {SEP_DASH, 0, s1->sign_no + 1 != s2->sign_no};

    if(inverted)
        res.modifier = SEP_EXT_INVERSION;
    else if(newline)
        res.modifier = SEP_EXT_NEWLINE;
    else if(ligature)
        res.modifier = SEP_EXT_LIGATURE;
    else if(s1->line_no != s2->line_no)
        res.modifier = SEP_EXT_LINEBREAK;

    if(s1->indicator && s2->indicator && s1->alignment == s2->alignment)
        res.connector = s1->phonographic == s2->phonographic ? (s1->phonographic ? SEP_INDICATOR_P : SEP_INDICATOR_L) : SEP_INDICATOR_M;
    else if((s1->indicator && (s1->alignment == ALIGNMENT_RIGHT || s1->alignment == ALIGNMENT_CENTER)) || (s2->indicator && (s2->alignment == ALIGNMENT_LEFT || s2->alignment == ALIGNMENT_CENTER)))
        res.connector = SEP_INDICATOR_0;
    else if(s1->compound_no != s2->compound_no)
        res.connector = SEP_COMPOUND;
    else if(s1->word_no != s2->word_no)
        res.connector = SEP_WORD;
    else if(s1->type == TYPE_NUMBER && s2->type == TYPE_NUMBER)
        res.connector = SEP_NUMBER;
    else if(s1->unknown_reading && s2->unknown_reading && s1->stem == s2->stem && s1->stem_null == s2->stem_null)
        res.connector = SEP_DOT;

    return res;
}


static Oid opened_condition_start(const char* s, size_t n, bool* no_condition)
{
    *no_condition = false;
    while(n-- != 0)
    {
        if(*s == ']')
            return CONDITION_LOST;
        if(n+1 >= strlen("⸣") && !cun_strcmp(s, "⸣"))
            return CONDITION_DAMAGED;
        if(n+1 >= strlen("›") && !cun_strcmp(s, "›"))
            return CONDITION_INSERTED;
        if(n+1 >= strlen("»") && !cun_strcmp(s, "»"))
            return CONDITION_DELETED;
        if(*s == '[') 
            return CONDITION_INTACT;
        if(n+1 >= strlen("⸢") && !cun_strcmp(s, "⸢"))
            return CONDITION_INTACT;
        if(n+1 >= strlen("‹") && !cun_strcmp(s, "‹"))
            return CONDITION_INTACT;
        if(n+1 >= strlen("«") && !cun_strcmp(s, "«"))
            return CONDITION_INTACT;
        ++s;
    }
    *no_condition = true;
    return CONDITION_INTACT;
}

static Oid opened_condition_end(const char* s, size_t n)
{
    s += n-1;
    size_t i = 0;
    while(i++ != n)
    {
        if(*s == ']')
            return CONDITION_INTACT;
        if(i+1 >= strlen("⸣") && !cun_strcmp(s, "⸣"))
            return CONDITION_INTACT;
        if(i+1 >= strlen("›") && !cun_strcmp(s, "›"))
            return CONDITION_INTACT;
        if(i+1 >= strlen("»") && !cun_strcmp(s, "»"))
            return CONDITION_INTACT;
        if(*s == '[') 
            return CONDITION_LOST;
        if(i+1 >= strlen("⸢") && !cun_strcmp(s, "⸢"))
            return CONDITION_DAMAGED;
        if(i+1 >= strlen("‹") && !cun_strcmp(s, "‹"))
            return CONDITION_INSERTED;
        if(i+1 >= strlen("«") && !cun_strcmp(s, "«"))
            return CONDITION_DELETED;
        --s;
    }
    return CONDITION_INTACT;
}


// HTML

static char* open_html(char* s, int changes, const State* state)
{
    if(changes >= LANGUAGE && state->language != LANGUAGE_SUMERIAN)
    {
        if(state->language == LANGUAGE_AKKADIAN)
            s = cun_strcpy(s, "<span class='akkadian'>");
        else if(state->language == LANGUAGE_HITTITE)
            s = cun_strcpy(s, "<span class='hittite'>");
        else if(state->language == LANGUAGE_EBLAITE)
            s = cun_strcpy(s, "<span class='eblaite'>");
        else
            s = cun_strcpy(s, "<span class='otherlanguage'>");
    }
    if(changes >= STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "<span class='stem'>");
    if(changes >= HIGHLIGHT && state->highlight)
        s = cun_strcpy(s, "<span class='highlight'>");
    if(changes >= PHONOGRAPHIC && !state->phonographic_null)
    {
        if(state->phonographic && state->language == LANGUAGE_SUMERIAN)
            s = cun_strcpy(s, "<span class='phonographic'>");
        else if(!state->phonographic && state->language != LANGUAGE_SUMERIAN)
            s = cun_strcpy(s, "<span class='logographic'>");
    }
    if(changes >= TYPE && (state->type != TYPE_VALUE || state->unknown_reading)  && state->type != TYPE_PUNCTUATION)
    {
        if(state->type == TYPE_NUMBER)
            s = cun_strcpy(s, "<span class='number'>");
        else if(state->type == TYPE_DESCRIPTION)
            s = cun_strcpy(s, "<span class='description'>");
        else if(state->type == TYPE_DAMAGE)
            s = cun_strcpy(s, "<span class='damage'>");
        else if(state->unknown_reading)
            s = cun_strcpy(s, "<span class='unknown_reading'>");
    }
    if(changes >= INDICATOR && state->indicator)
        s = cun_strcpy(s, "<span class='indicator'>");
    if(changes >= CONDITION && state->condition != CONDITION_INTACT)
    {
        if(state->condition == CONDITION_LOST)
            s = cun_strcpy(s, "<span class='lost'>");
        else if(state->condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "<span class='damaged'>");
        else if(state->condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "<span class='inserted'>");
        else if(state->condition == CONDITION_DELETED)
            s = cun_strcpy(s, "<span class='deleted'>");
        else if(state->condition == CONDITION_ERASED)
            s = cun_strcpy(s, "<span class='erased'>");
    }
    return s;
}

static char* close_html(char* s, int changes, const State* state)
{
    if(changes >= CONDITION && state->condition != CONDITION_INTACT)
        s = cun_strcpy(s, "</span>");
    if(changes >= INDICATOR && state->indicator)
        s = cun_strcpy(s, "</span>");
    if(changes >= TYPE && (state->type != TYPE_VALUE || state->unknown_reading) && state->type != TYPE_PUNCTUATION)
        s = cun_strcpy(s, "</span>");
    if(changes >= PHONOGRAPHIC && !state->phonographic_null && (state->phonographic == (state->language == LANGUAGE_SUMERIAN)))
        s = cun_strcpy(s, "</span>");
    if(changes >= HIGHLIGHT && state->highlight)
        s = cun_strcpy(s, "</span>");
    if(changes >= STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= LANGUAGE && state->language != LANGUAGE_SUMERIAN)
        s = cun_strcpy(s, "</span>");
    return s;
}


static char* open_condition_html(char* s, Oid condition)
{
    if(condition == CONDITION_LOST)
        s = cun_strcpy(s, "<span class='open-lost'></span>");
    else if(condition == CONDITION_DAMAGED)
        s = cun_strcpy(s, "<span class='open-damaged'></span>");
    else if(condition == CONDITION_INSERTED)
        s = cun_strcpy(s, "<span class='open-inserted'></span>");
    else if(condition == CONDITION_DELETED)
        s = cun_strcpy(s, "<span class='open-deleted'></span>");
    else if(condition == CONDITION_ERASED)
        s = cun_strcpy(s, "<span class='open-erased'></span>");
    return s;
}

static char* close_condition_html(char* s, Oid condition)
{
    if(condition == CONDITION_LOST)
        s = cun_strcpy(s, "<span class='close-lost'></span>");
    else if(condition == CONDITION_DAMAGED)
        s = cun_strcpy(s, "<span class='close-damaged'></span>");
    else if(condition == CONDITION_INSERTED)
        s = cun_strcpy(s, "<span class='close-inserted'></span>");
    else if(condition == CONDITION_DELETED)
        s = cun_strcpy(s, "<span class='close-deleted'></span>");
    else if(condition == CONDITION_ERASED)
        s = cun_strcpy(s, "<span class='close-erased'></span>");
    return s;
}


static char* write_simple_connector_html(char* s, int connector)
{
    if(connector == SEP_INDICATOR_L || connector == SEP_DOT || connector == SEP_NUMBER)
        *s++ = '.';
    else if(connector == SEP_INDICATOR_M)
        s = cun_strcpy(s, "<span class='indicator'>.</span>");
    else if(connector == SEP_INDICATOR_P || connector == SEP_DASH)
        *s++ = '-';
    else if(connector == SEP_WORD)
        s = cun_strcpy(s, "–");
    else if(connector == SEP_COMPOUND)
        *s++ = ' ';
    return s;
}

static char* write_modified_connector_html(char* s, const Connector c)
{   
    if(c.ellipsis)
    {
        s = write_simple_connector_html(s, c.connector);
        s = cun_strcpy(s, "…");
        s = write_simple_connector_html(s, c.connector);
    }
    else if(c.modifier == SEP_EXT_LIGATURE)
    {
        if(c.modifier == SEP_INDICATOR_M)
            s = cun_strcpy(s, "<span class='indicator'>+</span>");
        else
            *s++ = '+';
    }
    else if(c.modifier == SEP_EXT_LINEBREAK || c.modifier == SEP_EXT_NEWLINE)
    {
        if(c.connector != SEP_COMPOUND && c.connector != SEP_INDICATOR_L && c.connector != SEP_INDICATOR_P && c.connector != SEP_INDICATOR_M && c.connector != SEP_INDICATOR_0)
            s = write_simple_connector_html(s, c.connector);
    }
    else if(c.modifier == SEP_EXT_INVERSION)
    {
        if(c.connector == SEP_WORD)
            s = cun_strcpy(s, "—:");
        else if(c.connector == SEP_COMPOUND)
            s = cun_strcpy(s, " : ");
        else if(c.modifier == SEP_INDICATOR_M)
            s = cun_strcpy(s, "<span class='indicator'>:</span>");
        else
            *s++ = ':';
    }
    else
        s = write_simple_connector_html(s, c.connector);

    return s;
}

static size_t calculate_value_size_replacing_conditions_html(const char* s, size_t n)
{
    size_t size = 0;
    while(n-- != 0)
    {
        if(*s == ']')
            size += strlen("</span><span class='close-lost'></span>");
        else if(n+1 >= strlen("⸣") && !cun_strcmp(s, "⸣"))
            size += strlen("</span><span class='close-damaged'></span>");
        else if(n+1 >= strlen("›") && !cun_strcmp(s, "›"))
            size += strlen("</span><span class='close-inserted'></span>");
        else if(n+1 >= strlen("»") && !cun_strcmp(s, "»"))
            size += strlen("</span><span class='close-deleted'></span>");
        else if(*s == '[') 
            size += strlen("<span class='open-lost'></span><span class='lost'>");
        else if(n+1 >= strlen("⸢") && !cun_strcmp(s, "⸢"))
            size += strlen("<span class='close-damaged'><span class='damaged'>");
        else if(n+1 >= strlen("‹") && !cun_strcmp(s, "‹"))
            size += strlen("<span class='close-inserted'><span class='inserted'>");
        else if(n+1 >= strlen("«") && !cun_strcmp(s, "«"))
            size += strlen("<span class='close-deleted'><span class='deleted'>");
        else
            ++size;
    }
    return size;
}

static char* write_value_replacing_conditions_html(char* s, const char* v, size_t n)
{
    while(n-- != 0)
    {
        if(*s == ']')
            s = cun_strcpy(s, "</span><span class='close-lost'></span>");
        else if(n+1 >= strlen("⸣") && !cun_strcmp(s, "⸣"))
            s = cun_strcpy(s, "</span><span class='close-damaged'></span>");
        else if(n+1 >= strlen("›") && !cun_strcmp(s, "›"))
            s = cun_strcpy(s, "</span><span class='close-inserted'></span>");
        else if(n+1 >= strlen("»") && !cun_strcmp(s, "»"))
            s = cun_strcpy(s, "</span><span class='close-deleted'></span>");
        else if(*s == '[') 
            s = cun_strcpy(s, "<span class='open-lost'></span><span class='lost'>");
        else if(n+1 >= strlen("⸢") && !cun_strcmp(s, "⸢"))
            s = cun_strcpy(s, "<span class='close-damaged'><span class='damaged'>");
        else if(n+1 >= strlen("‹") && !cun_strcmp(s, "‹"))
            s = cun_strcpy(s, "<span class='close-inserted'><span class='inserted'>");
        else if(n+1 >= strlen("«") && !cun_strcmp(s, "«"))
            s = cun_strcpy(s, "<span class='close-deleted'><span class='deleted'>");
        else
            *s++ = *v;
        ++v;
    }
    return s;
}

Datum cuneiform_cun_agg_html_sfunc(PG_FUNCTION_ARGS)
{
    MemoryContext aggcontext;
    State* state;
    State state_old;

    if (!AggCheckCallContext(fcinfo, &aggcontext))
    {
        /* cannot be called directly because of internal-type argument */
        elog(ERROR, "array_agg_transfn called in non-aggregate context");
    }

    set_enums();

    state = init_state(fcinfo, aggcontext, &state_old);

    const text* value = PG_ARGISNULL(ARG_VALUE) ? NULL : PG_GETARG_TEXT_PP(ARG_VALUE);
    const text* sign = PG_ARGISNULL(ARG_SIGN) ? (state->unknown_reading ? value : NULL) : PG_GETARG_TEXT_PP(ARG_SIGN);

    const Oid variant_type = PG_ARGISNULL(ARG_VARIANT_TYPE) ? VARIANT_TYPE_DEFAULT : PG_GETARG_OID(ARG_VARIANT_TYPE);

    const bool inverted = PG_GETARG_BOOL(ARG_INVERTED);
    const bool newline = PG_GETARG_BOOL(ARG_NEWLINE);
    const bool ligature = PG_GETARG_BOOL(ARG_LIGATURE);

    const text* critics = PG_ARGISNULL(ARG_CRITICS) ? NULL : PG_GETARG_TEXT_PP(ARG_CRITICS);
    const text* comment = PG_ARGISNULL(ARG_COMMENT) ? NULL : PG_GETARG_TEXT_PP(ARG_COMMENT);

    const text* section = PG_ARGISNULL(ARG_SECTION) ? NULL : PG_GETARG_TEXT_PP(ARG_SECTION);

    const int32 string_size = VARSIZE_ANY_EXHDR(state->string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 value_size_final = calculate_value_size_replacing_conditions_html(VARDATA_ANY(value), value_size);
    const int32 sign_size = sign ? VARSIZE_ANY_EXHDR(sign) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    const int32 compound_comment_size = state_old.compound_comment ? VARSIZE_ANY_EXHDR(state_old.compound_comment) : 0;
    const int32 section_size = section ? VARSIZE_ANY_EXHDR(section) : 0;
    const int32 size = value_size_final + sign_size + critics_size + comment_size + compound_comment_size + section_size;
    if(state->string_capacity < string_size + size + MAX_EXTRA_SIZE_HTML)
    {
        state->string = (text*)repalloc(state->string, string_size + size + EXP_LINE_SIZE_HTML + VARHDRSZ);
        state->string_capacity += size + EXP_LINE_SIZE_HTML;
    }

    const bool x_value = value_size >= 8 ? *((char*)VARDATA_ANY(value) + value_size - 8) == 'x' : false;

    char* s = VARDATA(state->string)+string_size;

    bool no_condition;
    const Oid inner_condition = opened_condition_start((char*)VARDATA_ANY(value), value_size, &no_condition);
    if(!no_condition)
        state->condition = inner_condition;

    int changes = 0;
    if(!PG_ARGISNULL(0))
    { 
        changes = get_changes(&state_old, state);

        if(state_old.compound_no != state->compound_no && compound_comment_size)  // Word comments
        {
            *s++ = ' ';
            s = cun_strcpy(s, "<span class='word-comment'>");
            s = cun_memcpy(s, VARDATA_ANY(state_old.compound_comment), compound_comment_size);
            s = cun_strcpy(s, "</span>");
        }

        s = close_html(s, changes, &state_old);
        if(state->condition != state_old.condition || state_old.line_no != state->line_no)
            s = close_condition_html(s,state_old.condition);
        s = write_modified_connector_html(s, determine_connector(&state_old, state, inverted, newline, ligature));
        
        if (state_old.line_no != state->line_no)    // Newline
        {
            state->line_count += 1;
            state->lines = (Datum*) repalloc(state->lines, state->line_count * sizeof(Datum));
            SET_VARSIZE(state->string, s-VARDATA(state->string)+VARHDRSZ);
            state->lines[state->line_count-1] = PointerGetDatum(state->string);

            state->string = (text*) MemoryContextAllocZero(aggcontext, size + EXP_LINE_SIZE_HTML + VARHDRSZ);
            state->string_capacity = size + EXP_LINE_SIZE_HTML;
            SET_VARSIZE(state->string, VARHDRSZ);
            s = VARDATA(state->string);
        }
    }
    else
        changes = INT_MAX;   

    if(newline)   
        s = cun_strcpy(s, "<br class='internal-linebreak'>");   

    if(PG_ARGISNULL(0) || state->condition != state_old.condition || state_old.line_no != state->line_no)
        s = open_condition_html(s, state->condition);
    s = open_html(s, changes, state);

    if(!state->unknown_reading && value)
    {
        if(!cun_strcmp(VARDATA_ANY(value), "||"))
            s = cun_strcpy(s, "<span class='hspace'></span>");
        else if(!cun_strcmp(VARDATA_ANY(value), "="))
            s = cun_strcpy(s, "<span class='vspace'></span>");
        else if(!cun_strcmp(VARDATA_ANY(value), "|"))
            s = cun_strcpy(s, "<span class='hline'></span>");
        else if(!cun_strcmp(VARDATA_ANY(value), "–"))
            s = cun_strcpy(s, "<span class='vline'></span>");
        else
        {
            char* s_ = s;
            //s = cun_memcpy(s, VARDATA_ANY(value), value_size);
            s = write_value_replacing_conditions_html(s, VARDATA_ANY(value), value_size);
            if(state->capitalize && !state->indicator) {
                cun_capitalize(s_);
                state->capitalize = false;
            }
        } 

        if(variant_type == VARIANT_TYPE_REDUCED)
            s = cun_strcpy(s, "⁻");
        if(variant_type == VARIANT_TYPE_AUGMENTED)
            s = cun_strcpy(s, "⁺");

        if(critics_size || variant_type == VARIANT_TYPE_NONSTANDARD)
        {
            s = cun_strcpy(s, "<span class='critics'>");
            if(critics_size)
                s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);
            if(variant_type == VARIANT_TYPE_NONSTANDARD) 
                s = cun_strcpy(s, "!");
            s = cun_strcpy(s, "</span>");
        }

        if(sign && (variant_type == VARIANT_TYPE_NONSTANDARD || 
                    variant_type == VARIANT_TYPE_NONDEFAULT || 
                    state->type == TYPE_NUMBER || 
                    x_value))
        {
            s = cun_strcpy(s, "<span class='signspec'>");
            s = cun_memcpy(s, VARDATA_ANY(sign), sign_size);
            s = cun_strcpy(s, "</span>");
        }
    }
    else if(sign)
    {
        s = cun_memcpy(s, VARDATA_ANY(sign), sign_size);
        if(critics_size)
        {
            s = cun_strcpy(s, "<span class='critics'>");
            s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);
            s = cun_strcpy(s, "</span>");
        }
    }
    
    if(comment_size)
    {
        s = cun_strcpy(s, "<span class='comment'>");
        s = cun_memcpy(s, VARDATA_ANY(comment), comment_size);
        s = cun_strcpy(s, "</span>");
    }

    // Save new word comment
    if(!PG_ARGISNULL(ARG_COMPOUND_COMMENT))
    {
        const text* compound_comment = PG_GETARG_TEXT_PP(ARG_COMPOUND_COMMENT);
        const int32 size = VARSIZE_ANY_EXHDR(compound_comment);
        if(state->compound_comment_capacity < size)
        {
            state->compound_comment = (text*)repalloc(state->string, size + VARHDRSZ);
            state->compound_comment_capacity = size;
        }
        cun_memcpy(VARDATA_ANY(state->compound_comment), VARDATA_ANY(compound_comment), size);
        SET_VARSIZE(state->compound_comment, size+VARHDRSZ); 
    }
    else
        SET_VARSIZE(state->compound_comment, VARHDRSZ);

    if(!no_condition)
        state->condition = opened_condition_end((char*)VARDATA_ANY(value), value_size);

    SET_VARSIZE(state->string, s-VARDATA(state->string)+VARHDRSZ); 

    PG_RETURN_POINTER(state);
}

Datum cuneiform_cun_agg_html_finalfunc(PG_FUNCTION_ARGS)
{
    Assert(AggCheckCallContext(fcinfo, NULL));

    const State* state = PG_ARGISNULL(0) ? NULL : (State*) PG_GETARG_POINTER(0);
    if(state == NULL)
        PG_RETURN_NULL();

    // the finalfunc may not alter state, therefore we need to copy everything
    text* string = (text*) palloc0(VARSIZE(state->string) + 500);
    char* s = (char*)memcpy(VARDATA(string), VARDATA(state->string), VARSIZE_ANY_EXHDR(state->string)) + VARSIZE_ANY_EXHDR(state->string);
    Datum* lines = (Datum*) palloc0((state->line_count+1) * sizeof(Datum));
    memcpy(lines, state->lines, state->line_count * sizeof(Datum));
    lines[state->line_count] = PointerGetDatum(string);

    if(VARSIZE_ANY_EXHDR(state->compound_comment))  // Compound comments
    {
        *s++ = ' ';
        s = cun_strcpy(s, "<span class='word-comment'>");
        s = cun_memcpy(s, VARDATA_ANY(state->compound_comment), VARSIZE_ANY_EXHDR(state->compound_comment));
        s = cun_strcpy(s, "</span>");
    }

    s = close_html(s, INT_MAX, state);
    s = close_condition_html(s, state->condition);

    SET_VARSIZE(string, s-VARDATA(string)+VARHDRSZ);
       
    ArrayType* a = construct_array(lines, state->line_count+1, 25, -1, false, 'i');

    PG_RETURN_ARRAYTYPE_P(a);
}



// Code

static char* open_code(char* s, const State* s1, State* s2)
{
    if((s1 != NULL && s1->language != s2->language) || (s1 == NULL && s2->language != LANGUAGE_SUMERIAN))
    {
        if(s2->language == LANGUAGE_AKKADIAN)
            s = cun_strcpy(s, "%a ");
        else if(s2->language == LANGUAGE_EBLAITE)
            s = cun_strcpy(s, "%e ");
        else if(s2->language == LANGUAGE_HITTITE)
            s = cun_strcpy(s, "%h ");
        else if(s2->language == LANGUAGE_SUMERIAN)
            s = cun_strcpy(s, "%s ");
    }
    if(!s2->pn_type_null && (s1 == NULL || s1->pn_type != s2->pn_type || s2->pn_type_null || s1->compound_no != s2->compound_no))
    {
        if(s2->pn_type == PN_PERSON)
            s = cun_strcpy(s, "%person ");
        else if(s2->pn_type == PN_GOD)
            s = cun_strcpy(s, "%god ");
        else if(s2->pn_type == PN_PLACE)
            s = cun_strcpy(s, "%place ");
        else if(s2->pn_type == PN_WATER)
            s = cun_strcpy(s, "%water ");
        else if(s2->pn_type == PN_FIELD)
            s = cun_strcpy(s, "%field ");
        else if(s2->pn_type == PN_TEMPLE)
            s = cun_strcpy(s, "%temple ");
        else if(s2->pn_type == PN_MONTH)
            s = cun_strcpy(s, "%month ");
        else if(s2->pn_type == PN_OBJECT)
            s = cun_strcpy(s, "%object ");
        else if(s2->pn_type == PN_ETHNICITY)
            s = cun_strcpy(s, "%ethnicity ");
    }

    if(s1 != NULL && !s1->stem && s2->stem && !s1->stem_null && !s2->stem_null && s1->word_no == s2->word_no)
        *s++ = ';';

    if(s1 == NULL || s1->condition != s2->condition || s1->line_no != s2->line_no)
    {
        if(s2->condition == CONDITION_LOST)
            s = cun_strcpy(s, "[");
        else if(s2->condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "⸢");
        else if(s2->condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "‹");
        else if(s2->condition == CONDITION_DELETED)
            s = cun_strcpy(s, "«");
    }

    if(s2->capitalize) {
        *s++ = '&';
        s2->capitalize = false;
    }

    if(s2->indicator && (s1 == NULL || !s1->indicator || s1->alignment != s2->alignment || s1->phonographic != s2->phonographic || s1->phonographic_null || s1->line_no != s2->line_no))
    {
        if(s2->phonographic)
            *s++ = '<';
        else 
            *s++ = '{';
    }

    return s;
}


static char* close_code(char* s, const State* s1, const State* s2)
{
    if(s1->indicator && (s2 == NULL || !s2->indicator || s1->alignment != s2->alignment || s1->phonographic != s2->phonographic || s2->phonographic_null || s1->line_no != s2->line_no))
    {
        if(s1->phonographic)
            *s++ = '>';
        else 
            *s++ = '}';
    }

    if((s2 == NULL || s1->compound_no != s2->compound_no) && s1->compound_comment && VARSIZE_ANY_EXHDR(s1->compound_comment))
    {
        *s++ = ' ';
        *s++ = '(';
        s = cun_memcpy(s, VARDATA_ANY(s1->compound_comment), VARSIZE_ANY_EXHDR(s1->compound_comment));
        *s++ = ')';
    }

    if(s2 == NULL || s1->condition != s2->condition || s1->line_no != s2->line_no)
    {
        if(s1->condition == CONDITION_LOST)
            s = cun_strcpy(s, "]");
        else if(s1->condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "⸣");
        else if(s1->condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "›");
        else if(s1->condition == CONDITION_DELETED)
            s = cun_strcpy(s, "»");
    }

    if(s2 != NULL && s1->stem && !s2->stem && !s1->stem_null && !s2->stem_null && s1->word_no == s2->word_no)
        *s++ = ';';
        
    return s;
}


static char* write_simple_connector_code(char* s, int connector)
{
    if(connector == SEP_INDICATOR_L || connector == SEP_DOT || connector == SEP_NUMBER)
        *s++ = '.';
    else if(connector == SEP_INDICATOR_P || connector == SEP_DASH)
        *s++ = '-';
    else if(connector == SEP_WORD)
        s = cun_strcpy(s, "--");
    else if(connector == SEP_COMPOUND)
        *s++ = ' ';
    return s;
}

static char* write_modified_connector_code(char* s, const Connector c)
{   
    if(c.ellipsis)
    {
        s = write_simple_connector_code(s, c.connector);
        s = cun_strcpy(s, "…");
        s = write_simple_connector_code(s, c.connector);
    }
    else if(c.modifier == SEP_EXT_LIGATURE)
    {
        s = write_simple_connector_code(s, c.connector);
        *s++ = '+';
    }
    else if(c.modifier == SEP_EXT_LINEBREAK)
    {
        if(c.connector == SEP_INDICATOR_L || c.connector == SEP_INDICATOR_P || c.connector == SEP_INDICATOR_M || c.connector == SEP_INDICATOR_0)
            *s++ = '~';
        else if(c.connector != SEP_COMPOUND)
            s = write_simple_connector_code(s, c.connector);
    }
    else if(c.modifier == SEP_EXT_INVERSION)
    {
        if(c.connector == SEP_WORD)
            s = cun_strcpy(s, "--:");
        else if(c.connector == SEP_COMPOUND)
            s = cun_strcpy(s, " : ");
        else
            *s++ = ':';
    }
    else if(c.modifier == SEP_EXT_NEWLINE)
    {
        s = write_simple_connector_code(s, c.connector);
        *s++ = '/';
        if(c.connector == SEP_COMPOUND)
            *s++ = ' ';
    }
    else
        s = write_simple_connector_code(s, c.connector);

    return s;
}


Datum cuneiform_cun_agg_sfunc(PG_FUNCTION_ARGS)
{
    MemoryContext aggcontext;
    State* state;
    State state_old;

    if (!AggCheckCallContext(fcinfo, &aggcontext))
    {
        /* cannot be called directly because of internal-type argument */
        elog(ERROR, "array_agg_transfn called in non-aggregate context");
    }

    set_enums();

    state = init_state(fcinfo, aggcontext, &state_old);

    const text* value = PG_ARGISNULL(ARG_VALUE) ? NULL : PG_GETARG_TEXT_PP(ARG_VALUE);
    const text* sign = PG_ARGISNULL(ARG_SIGN) ? (state->unknown_reading ? value : NULL) : PG_GETARG_TEXT_PP(ARG_SIGN);

    const Oid variant_type = PG_ARGISNULL(ARG_VARIANT_TYPE) ? VARIANT_TYPE_DEFAULT : PG_GETARG_OID(ARG_VARIANT_TYPE);

    const bool inverted = PG_GETARG_BOOL(ARG_INVERTED);
    const bool newline = PG_GETARG_BOOL(ARG_NEWLINE);
    const bool ligature = PG_GETARG_BOOL(ARG_LIGATURE);

    const text* critics = PG_ARGISNULL(ARG_CRITICS) ? NULL : PG_GETARG_TEXT_PP(ARG_CRITICS);
    const text* comment = PG_ARGISNULL(ARG_COMMENT) ? NULL : PG_GETARG_TEXT_PP(ARG_COMMENT);

    const text* section = PG_ARGISNULL(ARG_SECTION) ? NULL : PG_GETARG_TEXT_PP(ARG_SECTION);

    const int32 string_size = VARSIZE_ANY_EXHDR(state->string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 sign_size = sign ? VARSIZE_ANY_EXHDR(sign) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    const int32 compound_comment_size = state_old.compound_comment ? VARSIZE_ANY_EXHDR(state_old.compound_comment) : 0;
    const int32 section_size = section ? VARSIZE_ANY_EXHDR(section) : 0;
    const int32 size = value_size + sign_size + critics_size + comment_size + compound_comment_size + section_size;
    if(state->string_capacity < string_size + size + MAX_EXTRA_SIZE_CODE)
    {
        state->string = (text*)repalloc(state->string, string_size + size + EXP_LINE_SIZE_CODE + VARHDRSZ);
        state->string_capacity += size + EXP_LINE_SIZE_CODE;
    }

    const bool x_value = value_size ? *((char*)VARDATA_ANY(value) + value_size - 1) == 'x' : false;

    char* s = VARDATA(state->string)+string_size;

    bool no_condition;
    const Oid inner_condition = opened_condition_start((char*)VARDATA_ANY(value), value_size, &no_condition);
    if(!no_condition)
        state->condition = inner_condition;

    if(string_size)
    { 
        s = close_code(s, &state_old, state);
        s = write_modified_connector_code(s, determine_connector(&state_old, state, inverted, newline, ligature));        

        if(state_old.line_no != state->line_no)    // Newline
        {
            state->line_count += 1;
            state->lines = (Datum*) repalloc(state->lines, state->line_count * sizeof(Datum));
            SET_VARSIZE(state->string, s-VARDATA(state->string)+VARHDRSZ);
            state->lines[state->line_count-1] = PointerGetDatum(state->string);
            state->string = (text*) MemoryContextAllocZero(aggcontext, size + EXP_LINE_SIZE_CODE + VARHDRSZ);
            state->string_capacity = size + EXP_LINE_SIZE_CODE;
            SET_VARSIZE(state->string, VARHDRSZ);
            s = VARDATA(state->string);
        }
    }    

    if(!state->section_null && (!string_size || state_old.section_null || state_old.section_no != state->section_no))
    {
        s = cun_strcpy(s, "%sec=");
        s = cun_memcpy(s, VARDATA_ANY(section), section_size);
        *s++ = ' ';
    }
    
    s = open_code(s, string_size ? &state_old : NULL, state);

    if(value)
    {
        const bool complex = state->unknown_reading && cun_has_char(VARDATA_ANY(sign), '.', sign_size);
        if(state->type == TYPE_DESCRIPTION)
            *s++ = '"';
        else if(complex)
            *s++= '|';
        s = cun_memcpy(s, VARDATA_ANY(value), value_size);
        if(state->type == TYPE_DESCRIPTION)
            *s++ = '"';
        else if(complex)
            *s++= '|';
    }

    if(variant_type == VARIANT_TYPE_NONSTANDARD)
        s = cun_strcpy(s, "!");
    if(critics_size)
        s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);

    if(sign && (variant_type == VARIANT_TYPE_NONSTANDARD || 
                variant_type == VARIANT_TYPE_NONDEFAULT || 
                variant_type == VARIANT_TYPE_REDUCED ||
                variant_type == VARIANT_TYPE_AUGMENTED ||
                state->type == TYPE_NUMBER ||
                x_value))
    {
        *s++ = '(';
        s = cun_memcpy(s, VARDATA_ANY(sign), sign_size);
        *s++ = ')';
    }

    if(comment_size)
    {
        *s++ = '(';
        s = cun_memcpy(s, VARDATA_ANY(comment), comment_size);
        *s++ = ')';
    }

    // Save new word comment
    if(!PG_ARGISNULL(ARG_COMPOUND_COMMENT))
    {
        const text* compound_comment = PG_GETARG_TEXT_PP(ARG_COMPOUND_COMMENT);
        const int32 size = VARSIZE_ANY_EXHDR(compound_comment);
        if(state->compound_comment_capacity < size)
        {
            state->compound_comment = (text*)repalloc(state->string, size + VARHDRSZ);
            state->compound_comment_capacity = size;
        }
        cun_memcpy(VARDATA_ANY(state->compound_comment), VARDATA_ANY(compound_comment), size);
        SET_VARSIZE(state->compound_comment, size+VARHDRSZ); 
    }
    else
        SET_VARSIZE(state->compound_comment, VARHDRSZ);

    if(!no_condition)
        state->condition = opened_condition_end((char*)VARDATA_ANY(value), value_size);

    SET_VARSIZE(state->string, s-VARDATA(state->string)+VARHDRSZ); 

    PG_RETURN_POINTER(state);
}

Datum cuneiform_cun_agg_finalfunc(PG_FUNCTION_ARGS)
{
    Assert(AggCheckCallContext(fcinfo, NULL));

    const State* state = PG_ARGISNULL(0) ? NULL : (State*) PG_GETARG_POINTER(0);
    if(state == NULL)
        PG_RETURN_NULL();

    // the finalfunc may not alter state, therefore we need to copy everything
    text* string = (text*) palloc0(VARSIZE(state->string) + 500);
    char* s = (char*)memcpy(VARDATA(string), VARDATA(state->string), VARSIZE_ANY_EXHDR(state->string)) + VARSIZE_ANY_EXHDR(state->string);
    Datum* lines = (Datum*) palloc0((state->line_count+1) * sizeof(Datum));
    memcpy(lines, state->lines, state->line_count * sizeof(Datum));
    lines[state->line_count] = PointerGetDatum(string);

    s = close_code(s, state, NULL);

    SET_VARSIZE(string, s-VARDATA(string)+VARHDRSZ);
       
    ArrayType* a = construct_array(lines, state->line_count+1, 25, -1, false, 'i');

    PG_RETURN_ARRAYTYPE_P(a);
}