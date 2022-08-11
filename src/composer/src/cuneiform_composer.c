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


#define  CONDITION          64
#define  LANGUAGE           32
#define  STEM               16
#define  HIGHLIGHT           8
#define  PHONOGRAPHIC        4
#define  TYPE                2
#define  INDICATOR           1


#define EXP_LINE_SIZE_CODE 100
#define MAX_EXTRA_SIZE_CODE 20
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

static int cun_strcmp(char* s1, const char* s2)
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
    bool highlight;
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
    }
    else
        state = (State*) PG_GETARG_POINTER(0);
    *state_old = *state;

    state->sign_no = PG_GETARG_INT32(4);
    state->word_no = PG_GETARG_INT32(5);
    state->compound_no = PG_GETARG_INT32(6);
    state->line_no = PG_GETARG_INT32(7);
    const HeapTupleHeader properties = PG_GETARG_HEAPTUPLEHEADER(8);
    state->type = DatumGetObjectId(GetAttributeByName(properties, "type", &isnull));
    state->phonographic = DatumGetBool(GetAttributeByName(properties, "phonographic", &state->phonographic_null));
    state->alignment = DatumGetObjectId(GetAttributeByName(properties, "alignment", &isnull));
    state->indicator = DatumGetBool(GetAttributeByName(properties, "indicator", &isnull));
    state->stem = PG_GETARG_BOOL(9);
    state->stem_null = PG_ARGISNULL(9);
    state->condition = PG_GETARG_OID(10);
    state->language = PG_GETARG_OID(11);
    state->highlight = PG_ARGISNULL(17) ? false : PG_GETARG_BOOL(17);

    state->unknown_reading = state->type == TYPE_SIGN;

    return state;
}


static int get_changes(const State* s1, const State* s2, const bool newline)
{
    int changes = 0;
    if(s1->indicator != s2->indicator || s1->alignment != s2->alignment)
        changes += INDICATOR;
    if(s1->type != s2->type || s1->unknown_reading != s2->unknown_reading)
        changes += TYPE;
    if(s1->phonographic != s2->phonographic || s1->phonographic_null != s2->phonographic_null)
        changes += PHONOGRAPHIC;
    if(s1->highlight != s2->highlight)
        changes += HIGHLIGHT;
    if(s1->stem != s2->stem || s1->stem_null != s2->stem_null)
        changes += STEM;
    if(s1->language != s2->language)
        changes += LANGUAGE;
    if(s1->condition != s2->condition || newline)
        changes += CONDITION;
    return changes;
}


static char* close_html(char* s, int changes, const State* state)
{
    if(changes >= INDICATOR && state->indicator)
        s = cun_strcpy(s, "</span>");
    if(changes >= TYPE && (state->type != TYPE_VALUE || state->unknown_reading) && state->type != TYPE_PUNCTUATION)
        s = cun_strcpy(s, "</span>");
    if(changes >= PHONOGRAPHIC && !state->phonographic_null && (state->phonographic == (state->language == LANGUAGE_SUMERIAN)))
        s = cun_strcpy(s, "</span>");
    if(changes >= PHONOGRAPHIC && state->phonographic && !state->phonographic_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= HIGHLIGHT && state->highlight)
        s = cun_strcpy(s, "</span>");
    if(changes >= STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= LANGUAGE && state->language != LANGUAGE_SUMERIAN)
        s = cun_strcpy(s, "</span>");
    if(changes >= CONDITION && state->condition != CONDITION_INTACT)
        s = cun_strcpy(s, "</span>");
    return s;
}

static char* open_html(char* s, int changes, const State* state)
{
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

    return s;
}

static char* close_code(char* s, int changes, const State* state)
{
    if(state->indicator && (changes & INDICATOR || changes & PHONOGRAPHIC))
    {
        if(state->phonographic & !state->phonographic_null)
            *s++ = '>';
        else 
            *s++ = '}';
    }
    if(changes & TYPE && state->type == TYPE_DESCRIPTION)
        *s++ = '"';
    if(changes & STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "⟩");
    if(changes & CONDITION)
    {
        if(state->condition == CONDITION_LOST)
            s = cun_strcpy(s, "]");
        else if(state->condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "⸣");
        else if(state->condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "›");
        else if(state->condition == CONDITION_DELETED)
            s = cun_strcpy(s, "»");
    }
    
    return s;
}

static char* open_code(char* s, int changes, const State* state)
{
    if(changes & CONDITION)
    {
        if(state->condition == CONDITION_LOST)
            s = cun_strcpy(s, "[");
        else if(state->condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "⸢");
        else if(state->condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "‹");
        else if(state->condition == CONDITION_DELETED)
            s = cun_strcpy(s, "«");
    }
    if(changes & STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "⟨");
    if(changes & TYPE && state->type == TYPE_DESCRIPTION)
        *s++ = '"';
    if(state->indicator && (changes & INDICATOR || changes & PHONOGRAPHIC))
    {
        if(state->phonographic && !state->phonographic_null)
            *s++ = '<';
        else 
            *s++ = '{';
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

    const text* value = PG_ARGISNULL(1) ? NULL : PG_GETARG_TEXT_PP(1);
    const text* sign = PG_ARGISNULL(2) ? (state->unknown_reading ? value : NULL) : PG_GETARG_TEXT_PP(2);

    const Oid variant_type = PG_ARGISNULL(3) ? VARIANT_TYPE_NONDEFAULT : PG_GETARG_OID(3);

    const bool inverted = PG_GETARG_BOOL(12);
    const bool newline = PG_GETARG_BOOL(13);

    const text* critics = PG_ARGISNULL(14) ? NULL : PG_GETARG_TEXT_PP(14);
    const text* comment = PG_ARGISNULL(15) ? NULL : PG_GETARG_TEXT_PP(15);

    const int32 string_size = VARSIZE_ANY_EXHDR(state->string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 sign_size = sign ? VARSIZE_ANY_EXHDR(sign) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    const int32 compound_comment_size = state_old.compound_comment ? VARSIZE_ANY_EXHDR(state_old.compound_comment) : 0;
    const int32 size = value_size + sign_size + critics_size + comment_size + compound_comment_size;
    if(state->string_capacity < string_size + size + MAX_EXTRA_SIZE_HTML)
    {
        state->string = (text*)repalloc(state->string, string_size + size + EXP_LINE_SIZE_HTML + VARHDRSZ);
        state->string_capacity += size + EXP_LINE_SIZE_HTML;
    }

    const bool x_value = value_size >= 8 ? *((char*)VARDATA_ANY(value) + value_size - 8) == 'x' : false;

    char* s = VARDATA(state->string)+string_size;

    int changes = 0;
    if(!PG_ARGISNULL(0))
    { 
        changes = get_changes(&state_old, state, state_old.line_no != state->line_no);

        if(state_old.compound_no != state->compound_no && compound_comment_size)  // Word comments
        {
            *s++ = ' ';
            s = cun_strcpy(s, "<span class='word-comment'>");
            s = cun_memcpy(s, VARDATA_ANY(state_old.compound_comment), compound_comment_size);
            s = cun_strcpy(s, "</span>");
        }

        s = close_html(s, changes, &state_old);


        // Connectors
        char connector = 0;

        if(inverted)
            connector = ':';
        else if(state_old.indicator && state->indicator && state_old.alignment == state->alignment)
            connector = state_old.phonographic && state->phonographic ? '-' : '.';
        else if(!(state_old.indicator && state_old.alignment == ALIGNMENT_RIGHT) && !(state->indicator && state->alignment == ALIGNMENT_LEFT))
        {       
            if(state_old.compound_no == state->compound_no)
                connector = state->unknown_reading && state_old.unknown_reading ? '.' : '-';
            else if(state_old.line_no == state->line_no)
                connector = ' ';
        }

        if(connector)
        {
            // Wrap connector between indicators in indicator span, if it isn't already
            if(state_old.indicator && state->indicator && state_old.alignment == state->alignment && changes > INDICATOR)
            {
                s = cun_strcpy(s, "<span class='indicator'>");
                *s++ = connector;
                s = cun_strcpy(s, "</span>");
            }
            else
                *s++ = connector;
        }
        
        if(state_old.sign_no+1 != state->sign_no)        // Ellipsis
        {
            s = cun_strcpy(s, "…");
            if(connector)
                *s++ = connector;
        }
        else if (state_old.line_no != state->line_no)    // Newline
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
            s = cun_memcpy(s, VARDATA_ANY(value), value_size);

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
    if(!PG_ARGISNULL(15))
    {
        const text* compound_comment = PG_GETARG_TEXT_PP(15);
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

    SET_VARSIZE(string, s-VARDATA(string)+VARHDRSZ);
       
    ArrayType* a = construct_array(lines, state->line_count+1, 25, -1, false, 'i');

    PG_RETURN_ARRAYTYPE_P(a);
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

    const text* value = PG_ARGISNULL(1) ? NULL : PG_GETARG_TEXT_PP(1);
    const text* sign = PG_ARGISNULL(2) ? (state->unknown_reading ? value : NULL) : PG_GETARG_TEXT_PP(2);

    const Oid variant_type = PG_ARGISNULL(3) ? VARIANT_TYPE_NONDEFAULT : PG_GETARG_OID(3);

    const bool inverted = PG_GETARG_BOOL(12);
    const bool newline = PG_GETARG_BOOL(13);

    const text* critics = PG_ARGISNULL(14) ? NULL : PG_GETARG_TEXT_PP(14);
    const text* comment = PG_ARGISNULL(15) ? NULL : PG_GETARG_TEXT_PP(15);

    const int32 string_size = VARSIZE_ANY_EXHDR(state->string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 sign_size = sign ? VARSIZE_ANY_EXHDR(sign) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    const int32 compound_comment_size = state_old.compound_comment ? VARSIZE_ANY_EXHDR(state_old.compound_comment) : 0;
    const int32 size = value_size + sign_size + critics_size + comment_size;
    if(state->string_capacity < string_size + size + MAX_EXTRA_SIZE_CODE)
    {
        state->string = (text*)repalloc(state->string, string_size + size + EXP_LINE_SIZE_CODE + VARHDRSZ);
        state->string_capacity += size + EXP_LINE_SIZE_CODE;
    }

    const bool x_value = value_size ? *((char*)VARDATA_ANY(value) + value_size - 1) == 'x' : false;

    char* s = VARDATA(state->string)+string_size;

    int changes = 0;
    if(string_size)
    { 
        changes = get_changes(&state_old, state, state_old.line_no != state->line_no);

        if(state_old.compound_no != state->compound_no && compound_comment_size)  // Compound comments
        {
            *s++ = ' ';
            *s++ = '(';
            s = cun_memcpy(s, VARDATA_ANY(state_old.compound_comment), compound_comment_size);
            *s++ = ')';
        }

        s = close_code(s, changes, &state_old);


        // Connectors
        char connector = 0;

        if(inverted)
            connector = ':';
        else if(state_old.indicator && state->indicator && state_old.alignment == state->alignment)
            connector = state_old.phonographic && state->phonographic ? '-' : '.';
        else if(!(state_old.indicator && state_old.alignment == ALIGNMENT_RIGHT) && !(state->indicator && state->alignment == ALIGNMENT_LEFT))
        {       
            if(state_old.compound_no == state->compound_no)
                connector = state_old.unknown_reading && state->unknown_reading ? '.' : '-';
            else if(state_old.line_no == state->line_no)
                connector = ' ';
        }

        if(connector)
            *s++ = connector;
        
        if(state_old.sign_no+1 != state->sign_no)        // Ellipsis
        {
            s = cun_strcpy(s, "…");
            if(connector)
                *s++ = connector;
        }
        else if (state_old.line_no != state->line_no)    // Newline
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
    else
        changes = INT_MAX;      

    
    s = open_code(s, changes, state);

    if(!state->unknown_reading)
    {
        if(value)
        {
            s = cun_memcpy(s, VARDATA_ANY(value), value_size);

            if(variant_type == VARIANT_TYPE_REDUCED)
                s = cun_strcpy(s, "⁻");
            if(variant_type == VARIANT_TYPE_AUGMENTED)
                s = cun_strcpy(s, "⁺");
        }

        if(critics_size)
            s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);
        if(variant_type == VARIANT_TYPE_NONSTANDARD)
            s = cun_strcpy(s, "!");

        if(sign && (variant_type == VARIANT_TYPE_NONSTANDARD || 
                    variant_type == VARIANT_TYPE_NONDEFAULT || 
                    state->type == TYPE_NUMBER ||
                    x_value))
        {
            *s++ = '(';
            s = cun_memcpy(s, VARDATA_ANY(sign), sign_size);
            *s++ = ')';
        }
    }
    else if(sign)
    {
        s = cun_memcpy(s, VARDATA_ANY(sign), sign_size);
        if(critics_size)
            s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);
    }

    if(comment_size)
    {
        *s++ = '(';
        s = cun_memcpy(s, VARDATA_ANY(comment), comment_size);
        *s++ = ')';
    }

    // Save new word comment
    if(!PG_ARGISNULL(15))
    {
        const text* compound_comment = PG_GETARG_TEXT_PP(15);
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

    if(VARSIZE_ANY_EXHDR(state->compound_comment))  // Compound comments
    {
        *s++ = ' ';
        *s++ = '(';
        s = cun_memcpy(s, VARDATA_ANY(state->compound_comment), VARSIZE_ANY_EXHDR(state->compound_comment));
        *s++ = ')';
    }

    s = close_code(s, INT_MAX, state);

    SET_VARSIZE(string, s-VARDATA(string)+VARHDRSZ);
       
    ArrayType* a = construct_array(lines, state->line_count+1, 25, -1, false, 'i');

    PG_RETURN_ARRAYTYPE_P(a);
}