#include "cuneiform_composer.h"

#include <math.h>

#include <fmgr.h>
#include <executor/executor.h>
#include <utils/builtins.h>
#include <access/htup_details.h>
#include <catalog/pg_type.h>
#include <utils/array.h>



#define  TYPE_VALUE         25080
#define  TYPE_SIGN          25082
#define  TYPE_NUMBER        25084
#define  TYPE_PUNCTUATION   25086
#define  TYPE_DESCRIPTION   25088
#define  TYPE_DAMAGE        25090

#define  ALIGNMENT_LEFT     24538
#define  ALIGNMENT_RIGHT    24540
#define  ALIGNMENT_CENTER   24542

#define  LANGUAGE_SUMERIAN  24546
#define  LANGUAGE_AKKADIAN  24548
#define  LANGUAGE_OTHER     24550

#define  CONDITION_INTACT   25010
#define  CONDITION_DAMAGED  25012
#define  CONDITION_LOST     25014
#define  CONDITION_INSERTED 25016
#define  CONDITION_DELETED  25018


#define  CONDITION          32
#define  LANGUAGE           16
#define  STEM                8
#define  PHONOGRAPHIC        4
#define  TYPE                2
#define  INDICATOR           1


#define EXP_LINE_SIZE_CODE 100
#define MAX_EXTRA_SIZE_CODE 20
#define EXP_LINE_SIZE_HTML 1000
#define MAX_EXTRA_SIZE_HTML 200


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

typedef struct State
{
    Datum* lines;
    int32 line_count;
    text* string;
    size_t string_capacity;

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
} State;

State* init_state(FunctionCallInfo fcinfo, MemoryContext memcontext, State* state_old)
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
    }
    else
        state = (State*) PG_GETARG_POINTER(0);
    *state_old = *state;

    state->unknown_reading = PG_GETARG_BOOL(2);
    state->sign_no = PG_GETARG_INT32(3);
    state->word_no = PG_GETARG_INT32(4);
    state->compound_no = PG_GETARG_INT32(5);
    state->line_no = PG_GETARG_INT32(6);
    const HeapTupleHeader properties = PG_GETARG_HEAPTUPLEHEADER(7);
    state->type = DatumGetObjectId(GetAttributeByName(properties, "type", &isnull));
    state->phonographic = DatumGetBool(GetAttributeByName(properties, "phonographic", &state->phonographic_null));
    state->alignment = DatumGetObjectId(GetAttributeByName(properties, "alignment", &isnull));
    state->indicator = DatumGetBool(GetAttributeByName(properties, "indicator", &isnull));
    state->stem = PG_GETARG_BOOL(8);
    state->stem_null = PG_ARGISNULL(8);
    state->condition = PG_GETARG_OID(9);
    state->language = PG_GETARG_OID(10);

    return state;
}


int get_changes(const State* s1, const State* s2, const bool newline)
{
    int changes = 0;
    if(s1->indicator != s2->indicator || s1->alignment != s2->alignment)
        changes += INDICATOR;
    if(s1->type != s2->type)
        changes += TYPE;
    if(s1->phonographic != s2->phonographic || s1->phonographic_null != s2->phonographic_null)
        changes += PHONOGRAPHIC;
    if(s1->stem != s2->stem || s1->stem_null != s2->stem_null)
        changes += STEM;
    if(s1->language != s2->language)
        changes += LANGUAGE;
    if(s1->condition != s2->condition || newline)
        changes += CONDITION;
    return changes;
}


char* close_html(char* s, int changes, const State* state)
{
    if(changes >= INDICATOR && state->indicator)
        s = cun_strcpy(s, "</span>");
    if(changes >= TYPE && state->type != TYPE_VALUE)
        s = cun_strcpy(s, "</span>");
    if(changes >= PHONOGRAPHIC && state->phonographic && !state->phonographic_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= LANGUAGE && state->language != LANGUAGE_SUMERIAN)
        s = cun_strcpy(s, "</span>");
    if(changes >= CONDITION && state->condition != CONDITION_INTACT)
        s = cun_strcpy(s, "</span>");
    return s;
}

char* open_html(char* s, int changes, const State* state)
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
    }
    if(changes >= LANGUAGE && state->language != LANGUAGE_SUMERIAN)
    {
        if(state->language == LANGUAGE_AKKADIAN)
            s = cun_strcpy(s, "<span class='akkadian'>");
        else
            s = cun_strcpy(s, "<span class='otherlanguage'>");
    }
    if(changes >= STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "<span class='stem'>");
    if(changes >= PHONOGRAPHIC && state->phonographic && !state->phonographic_null)
        s = cun_strcpy(s, "<span class='phonographic'>");
    if(changes >= TYPE && state->type != TYPE_VALUE)
    {
        if(state->type == TYPE_NUMBER)
            s = cun_strcpy(s, "<span class='number'>");
        else if(state->type == TYPE_PUNCTUATION)
            s = cun_strcpy(s, "<span class='punctuation'>");
        else if(state->type == TYPE_DESCRIPTION)
            s = cun_strcpy(s, "<span class='description'>");
        else if(state->type == TYPE_DAMAGE)
            s = cun_strcpy(s, "<span class='damage'>");
    }
    if(changes >= INDICATOR && state->indicator)
        s = cun_strcpy(s, "<span class='indicator'>");

    return s;
}

char* close_code(char* s, int changes, const State* state)
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

char* open_code(char* s, int changes, const State* state)
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
    bool isnull;

    if (!AggCheckCallContext(fcinfo, &aggcontext))
    {
        /* cannot be called directly because of internal-type argument */
        elog(ERROR, "array_agg_transfn called in non-aggregate context");
    }

    state = init_state(fcinfo, aggcontext, &state_old);

    const text* value = PG_ARGISNULL(1) ? NULL : PG_GETARG_TEXT_PP(1);

    const bool inverted = PG_GETARG_BOOL(11);
    const bool newline = PG_GETARG_BOOL(12);

    const text* critics = PG_ARGISNULL(13) ? NULL : PG_GETARG_TEXT_PP(13);
    const text* comment = PG_ARGISNULL(14) ? NULL : PG_GETARG_TEXT_PP(14);

    const int32 string_size = VARSIZE_ANY_EXHDR(state->string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    const int32 size = value_size + critics_size + comment_size;
    if(state->string_capacity < string_size + size + MAX_EXTRA_SIZE_HTML)
    {
        state->string = (text*)repalloc(state->string, string_size + size + EXP_LINE_SIZE_HTML + VARHDRSZ);
        state->string_capacity += size + EXP_LINE_SIZE_HTML;
    }

    char* s = VARDATA(state->string)+string_size;

    int changes = 0;
    if(!PG_ARGISNULL(0))
    { 
        changes = get_changes(&state_old, state, state_old.line_no != state->line_no);

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

            state->string = (text*) MemoryContextAllocZero(aggcontext, size + EXP_LINE_SIZE_HTML + VARHDRSZ);
            state->string_capacity = size + EXP_LINE_SIZE_HTML;
            SET_VARSIZE(state->string, VARHDRSZ);
            s = VARDATA(state->string);
        }
    }
    else
        changes = INT_MAX;      

    
    s = open_html(s, changes, state);

    if(value)
        s = cun_memcpy(s, VARDATA_ANY(value), value_size);

    if(critics_size)
    {
        s = cun_strcpy(s, "<span class='critics'>");
        s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);
        s = cun_strcpy(s, "</span>");
    }

    if(comment_size)
    {
        s = cun_strcpy(s, "<span class='comment'>");
        s = cun_memcpy(s, VARDATA_ANY(comment), comment_size);
        s = cun_strcpy(s, "</span>");
    }

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
    SET_VARSIZE(string, VARSIZE(state->string) + 500);
    char* s = ((char*)memcpy((void *)VARDATA(string), (void *)VARDATA(state->string), VARSIZE(state->string))) + VARSIZE(state->string);
    Datum* lines = (Datum*) palloc0((state->line_count+1) * sizeof(Datum));
    memcpy(lines, state->lines, state->line_count * sizeof(Datum));
    lines[state->line_count] = PointerGetDatum(string);

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
    bool isnull;

    if (!AggCheckCallContext(fcinfo, &aggcontext))
    {
        /* cannot be called directly because of internal-type argument */
        elog(ERROR, "array_agg_transfn called in non-aggregate context");
    }

    state = init_state(fcinfo, aggcontext, &state_old);

    const text* value = PG_ARGISNULL(1) ? NULL : PG_GETARG_TEXT_PP(1);

    const bool inverted = PG_GETARG_BOOL(11);
    const bool newline = PG_GETARG_BOOL(12);

    const text* critics = PG_ARGISNULL(13) ? NULL : PG_GETARG_TEXT_PP(13);
    const text* comment = PG_ARGISNULL(14) ? NULL : PG_GETARG_TEXT_PP(14);

    const int32 string_size = VARSIZE_ANY_EXHDR(state->string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    const int32 size = value_size + critics_size + comment_size;
    if(state->string_capacity < string_size + size + MAX_EXTRA_SIZE_CODE)
    {
        state->string = (text*)repalloc(state->string, string_size + size + EXP_LINE_SIZE_CODE + VARHDRSZ);
        state->string_capacity += size + EXP_LINE_SIZE_CODE;
    }

    char* s = VARDATA(state->string)+string_size;

    int changes = 0;
    if(string_size)
    { 
        changes = get_changes(&state_old, state, state_old.line_no != state->line_no);

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

    if(value)
        s = cun_memcpy(s, VARDATA_ANY(value), value_size);

    if(critics_size)
        s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);

    if(comment_size)
    {
        *s++ = '(';
        s = cun_memcpy(s, VARDATA_ANY(comment), comment_size);
        *s++ = ')';
    }

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
    SET_VARSIZE(string, VARSIZE(state->string) + 500);
    char* s = ((char*)memcpy((void *)VARDATA(string), (void *)VARDATA(state->string), VARSIZE(state->string))) + VARSIZE(state->string);
    Datum* lines = (Datum*) palloc0((state->line_count+1) * sizeof(Datum));
    memcpy(lines, state->lines, state->line_count * sizeof(Datum));
    lines[state->line_count] = PointerGetDatum(string);

    s = close_code(s, INT_MAX, state);

    SET_VARSIZE(string, s-VARDATA(string)+VARHDRSZ);
       
    ArrayType* a = construct_array(lines, state->line_count+1, 25, -1, false, 'i');

    PG_RETURN_ARRAYTYPE_P(a);
}