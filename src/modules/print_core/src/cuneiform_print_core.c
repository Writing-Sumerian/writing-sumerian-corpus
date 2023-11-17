#include "cuneiform_print_core.h"

#include <fmgr.h>
#include <executor/spi.h>

PG_MODULE_MAGIC;

static cunEnumType ENUM_TYPE;
static cunEnumIndicatorType ENUM_INDICATOR_TYPE;
static cunEnumLanguage ENUM_LANGUAGE;
static cunEnumCondition ENUM_CONDITION;
static cunEnumVariantType ENUM_VARIANT_TYPE;
static cunEnumPN ENUM_PN;

static bool enums_set = false;


void set_enums()
{
    bool isnull;

    if(enums_set)
        return;

    SPI_connect();

    SPI_execute("SELECT 'sumerian'::language, 'akkadian'::language, 'hittite'::language, 'eblaite'::language, 'other'::language", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        ENUM_LANGUAGE.sumerian = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        ENUM_LANGUAGE.akkadian = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        ENUM_LANGUAGE.hittite = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        ENUM_LANGUAGE.eblaite = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        ENUM_LANGUAGE.other = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
    }
    SPI_execute("SELECT 'none'::indicator_type, 'left'::indicator_type, 'right'::indicator_type, 'center'::indicator_type", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        ENUM_INDICATOR_TYPE.none = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        ENUM_INDICATOR_TYPE.left = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        ENUM_INDICATOR_TYPE.right = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        ENUM_INDICATOR_TYPE.center = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
    }
    SPI_execute("SELECT 'value'::sign_type, 'sign'::sign_type, 'number'::sign_type, 'punctuation'::sign_type,"
                "       'description'::sign_type, 'damage'::sign_type", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        ENUM_TYPE.value = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        ENUM_TYPE.sign = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        ENUM_TYPE.number = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        ENUM_TYPE.punctuation = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        ENUM_TYPE.description = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
        ENUM_TYPE.damage = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 6, &isnull));
    }
    SPI_execute("SELECT 'intact'::sign_condition, 'damaged'::sign_condition, 'lost'::sign_condition,"
                "       'inserted'::sign_condition, 'deleted'::sign_condition, 'erased'::sign_condition", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        ENUM_CONDITION.intact = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        ENUM_CONDITION.damaged = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        ENUM_CONDITION.lost = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        ENUM_CONDITION.inserted = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        ENUM_CONDITION.deleted = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
        ENUM_CONDITION.erased = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 6, &isnull));
    }
    SPI_execute("SELECT 'default'::sign_variant_type, 'nondefault'::sign_variant_type, 'reduced'::sign_variant_type,"
                "       'augmented'::sign_variant_type, 'nonstandard'::sign_variant_type", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        ENUM_VARIANT_TYPE.default_variant = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        ENUM_VARIANT_TYPE.nondefault = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        ENUM_VARIANT_TYPE.reduced = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        ENUM_VARIANT_TYPE.augmented = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        ENUM_VARIANT_TYPE.nonstandard = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
    }
    SPI_execute("SELECT 'person'::pn_type, 'god'::pn_type, 'place'::pn_type, 'water'::pn_type, 'field'::pn_type,"
                "       'temple'::pn_type, 'month'::pn_type, 'object'::pn_type, 'ethnicity'::pn_type", true, 1);
    if(SPI_tuptable != NULL && SPI_processed == 1)
    {
        const HeapTuple tuple = SPI_tuptable->vals[0];
        const TupleDesc tupdesc = SPI_tuptable->tupdesc;
        ENUM_PN.person = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 1, &isnull));
        ENUM_PN.god = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 2, &isnull));
        ENUM_PN.place = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 3, &isnull));
        ENUM_PN.water = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 4, &isnull));
        ENUM_PN.field = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 5, &isnull));
        ENUM_PN.temple = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 6, &isnull));
        ENUM_PN.month = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 7, &isnull));
        ENUM_PN.object = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 8, &isnull));
        ENUM_PN.ethnicity = DatumGetObjectId(SPI_getbinval(tuple, tupdesc, 9, &isnull));
    }
    
    SPI_finish();

    enums_set = true;
}

cunEnumType *cun_enum_type()
{
    return &ENUM_TYPE;
}
cunEnumIndicatorType *cun_enum_indicator_type()
{
    return &ENUM_INDICATOR_TYPE;
}
cunEnumLanguage *cun_enum_language()
{
    return &ENUM_LANGUAGE;
}
cunEnumCondition *cun_enum_condition()
{
    return &ENUM_CONDITION;
}
cunEnumVariantType *cun_enum_variant_type()
{
    return &ENUM_VARIANT_TYPE;
}
cunEnumPN *cun_enum_pn()
{
    return &ENUM_PN;
}


char* cun_memcpy(char* s1, const char* s2, size_t n)
{
    while(n-- != 0)
        *s1++ = *s2++;
    return s1;
}

char* cun_strcpy(char* s1, const char* s2)
{
    while(*s2 != '\0')
        *s1++ = *s2++;
    return s1;
}

int cun_strcmp(const char* s1, const char* s2)
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

void cun_capitalize(char* s)
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

bool cun_has_char(const char* s, char c, size_t n)
{
    while(n-- != 0)
        if(s[n] == c)
            return true;
    return false;
}



State* cun_init_state(FunctionCallInfo fcinfo, MemoryContext memcontext, State* state_old)
{
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
    state->type = PG_GETARG_OID(ARG_TYPE);
    state->phonographic = PG_GETARG_BOOL(ARG_PHONOGRAPHIC);
    state->phonographic_null = PG_ARGISNULL(ARG_PHONOGRAPHIC);
    state->indicator_type = PG_GETARG_OID(ARG_INDICATOR_TYPE);
    state->stem = PG_GETARG_BOOL(ARG_STEM);
    state->stem_null = PG_ARGISNULL(ARG_STEM);
    state->condition = PG_GETARG_OID(ARG_CONDITION);
    state->language = PG_GETARG_OID(ARG_LANGUAGE);
    state->pn_type = PG_GETARG_OID(ARG_PN_TYPE);
    state->pn_type_null = PG_ARGISNULL(ARG_PN_TYPE);
    state->highlight = PG_ARGISNULL(ARG_HIGHLIGHT) ? false : PG_GETARG_BOOL(ARG_HIGHLIGHT);

    state->capitalize = state_old->capitalize || (PG_GETARG_BOOL(ARG_CAPITALIZED) && state_old->word_no != state->word_no);

    state->unknown_reading = state->type == ENUM_TYPE.sign;

    return state;
}


int cun_get_changes(const State* s1, const State* s2)
{
    int changes = 0;
    if(s1->condition != s2->condition)
        changes += CONDITION;
    if(s1->indicator_type != s2->indicator_type)
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


Connector cun_determine_connector(const State* s1, const State* s2, bool inverted, bool newline, bool ligature)
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

    if(s1->indicator_type != ENUM_INDICATOR_TYPE.none && s2->indicator_type == s1->indicator_type)
        res.connector = s1->phonographic == s2->phonographic ? (s1->phonographic ? SEP_INDICATOR_P : SEP_INDICATOR_L) : SEP_INDICATOR_M;
    else if((s1->indicator_type == ENUM_INDICATOR_TYPE.right || s1->indicator_type == ENUM_INDICATOR_TYPE.center) || (s2->indicator_type == ENUM_INDICATOR_TYPE.left || s2->indicator_type == ENUM_INDICATOR_TYPE.center))
        res.connector = SEP_INDICATOR_0;
    else if(s1->compound_no != s2->compound_no)
        res.connector = SEP_COMPOUND;
    else if(s1->word_no != s2->word_no)
        res.connector = SEP_WORD;
    else if(s1->type == ENUM_TYPE.number && s2->type == ENUM_TYPE.number)
        res.connector = SEP_NUMBER;
    else if(s1->unknown_reading && s2->unknown_reading && s1->stem == s2->stem && s1->stem_null == s2->stem_null)
        res.connector = SEP_DOT;

    return res;
}


Oid cun_opened_condition_start(const char* s, size_t n, bool* no_condition)
{
    *no_condition = false;
    while(n-- != 0)
    {
        if(*s == ']')
            return ENUM_CONDITION.lost;
        if(n+1 >= strlen("⸣") && !cun_strcmp(s, "⸣"))
            return ENUM_CONDITION.damaged;
        if(n+1 >= strlen("›") && !cun_strcmp(s, "›"))
            return ENUM_CONDITION.inserted;
        if(n+1 >= strlen("»") && !cun_strcmp(s, "»"))
            return ENUM_CONDITION.deleted;
        if(*s == '[') 
            return ENUM_CONDITION.intact;
        if(n+1 >= strlen("⸢") && !cun_strcmp(s, "⸢"))
            return ENUM_CONDITION.intact;
        if(n+1 >= strlen("‹") && !cun_strcmp(s, "‹"))
            return ENUM_CONDITION.intact;
        if(n+1 >= strlen("«") && !cun_strcmp(s, "«"))
            return ENUM_CONDITION.intact;
        ++s;
    }
    *no_condition = true;
    return ENUM_CONDITION.intact;
}

Oid cun_opened_condition_end(const char* s, size_t n)
{
    s += n-1;
    size_t i = 0;
    while(i++ != n)
    {
        if(*s == ']')
            return ENUM_CONDITION.intact;
        if(i+1 >= strlen("⸣") && !cun_strcmp(s, "⸣"))
            return ENUM_CONDITION.intact;
        if(i+1 >= strlen("›") && !cun_strcmp(s, "›"))
            return ENUM_CONDITION.intact;
        if(i+1 >= strlen("»") && !cun_strcmp(s, "»"))
            return ENUM_CONDITION.intact;
        if(*s == '[') 
            return ENUM_CONDITION.lost;
        if(i+1 >= strlen("⸢") && !cun_strcmp(s, "⸢"))
            return ENUM_CONDITION.damaged;
        if(i+1 >= strlen("‹") && !cun_strcmp(s, "‹"))
            return ENUM_CONDITION.inserted;
        if(i+1 >= strlen("«") && !cun_strcmp(s, "«"))
            return ENUM_CONDITION.deleted;
        --s;
    }
    return ENUM_CONDITION.intact;
}