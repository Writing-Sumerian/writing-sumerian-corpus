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


char* cun_index(char* s, size_t n)
{
    char* end = s+n;
    while(s < end && (*s < '0' || *s > '9') && *s != 'x')
        s++;
    return s;
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

struct States
{
    Oid alignment;
    bool indicator;
    Oid type;
    bool phonographic;
    Oid language;
    Oid condition;
    bool stem;
    bool phonographic_null;
    bool stem_null;
};

int get_changes(struct States s1, struct States s2, bool newline)
{
    int changes = 0;
    if(s1.indicator != s2.indicator || s1.alignment != s2.alignment)
        changes += INDICATOR;
    if(s1.type != s2.type)
        changes += TYPE;
    if(s1.phonographic != s2.phonographic || s1.phonographic_null != s2.phonographic_null)
        changes += PHONOGRAPHIC;
    if(s1.stem != s2.stem || s1.stem_null != s2.stem_null)
        changes += STEM;
    if(s1.language != s2.language)
        changes += LANGUAGE;
    if(s1.condition != s2.condition || newline)
        changes += CONDITION;
    return changes;
}

char* close_html(char* s, int changes, struct States states)
{
    if(changes >= INDICATOR && states.indicator)
        s = cun_strcpy(s, "</span>");
    if(changes >= TYPE && states.type != TYPE_VALUE)
        s = cun_strcpy(s, "</span>");
    if(changes >= PHONOGRAPHIC && states.phonographic && !states.phonographic_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= STEM && states.stem && !states.stem_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= LANGUAGE && states.language != LANGUAGE_SUMERIAN)
        s = cun_strcpy(s, "</span>");
    if(changes >= CONDITION && states.condition != CONDITION_INTACT)
        s = cun_strcpy(s, "</span>");
    return s;
}

char* open_html(char* s, int changes, struct States states)
{
    if(changes >= CONDITION && states.condition != CONDITION_INTACT)
    {
        if(states.condition == CONDITION_LOST)
            s = cun_strcpy(s, "<span class='lost'>");
        else if(states.condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "<span class='damaged'>");
        else if(states.condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "<span class='inserted'>");
        else if(states.condition == CONDITION_DELETED)
            s = cun_strcpy(s, "<span class='deleted'>");
    }
    if(changes >= LANGUAGE && states.language != LANGUAGE_SUMERIAN)
    {
        if(states.language == LANGUAGE_AKKADIAN)
            s = cun_strcpy(s, "<span class='akkadian'>");
        else
            s = cun_strcpy(s, "<span class='otherlanguage'>");
    }
    if(changes >= STEM && states.stem && !states.stem_null)
        s = cun_strcpy(s, "<span class='stem'>");
    if(changes >= PHONOGRAPHIC && states.phonographic && !states.phonographic_null)
        s = cun_strcpy(s, "<span class='phonographic'>");
    if(changes >= TYPE && states.type != TYPE_VALUE)
    {
        if(states.type == TYPE_NUMBER)
            s = cun_strcpy(s, "<span class='number'>");
        else if(states.type == TYPE_PUNCTUATION)
            s = cun_strcpy(s, "<span class='punctuation'>");
        else if(states.type == TYPE_DESCRIPTION)
            s = cun_strcpy(s, "<span class='description'>");
        else if(states.type == TYPE_DAMAGE)
            s = cun_strcpy(s, "<span class='damage'>");
    }
    if(changes >= INDICATOR && states.indicator)
        s = cun_strcpy(s, "<span class='indicator'>");

    return s;
}


Datum cuneiform_cun_agg_html_sfunc(PG_FUNCTION_ARGS)
{
    bool isnull;

    const HeapTupleHeader state = PG_GETARG_HEAPTUPLEHEADER(0);
    const text* value = PG_ARGISNULL(1) ? NULL : PG_GETARG_TEXT_PP(1);
    const bool unknown_reading = PG_GETARG_BOOL(2);
    const int32 sign_no = PG_GETARG_INT32(3);
    const int32 word_no = PG_GETARG_INT32(4);
    const int32 compound_no = PG_GETARG_INT32(5);
    const int32 line_no = PG_GETARG_INT32(6);

    struct States states;
    const HeapTupleHeader properties = PG_GETARG_HEAPTUPLEHEADER(7);
    states.type = DatumGetObjectId(GetAttributeByName(properties, "type", &isnull));
    states.phonographic = DatumGetBool(GetAttributeByName(properties, "phonographic", &states.phonographic_null));
    states.alignment = DatumGetObjectId(GetAttributeByName(properties, "alignment", &isnull));
    states.indicator = DatumGetBool(GetAttributeByName(properties, "indicator", &isnull));
    states.stem = PG_GETARG_BOOL(8);
    states.stem_null = PG_ARGISNULL(8);
    states.condition = PG_GETARG_OID(9);
    states.language = PG_GETARG_OID(10);

    const bool inverted = PG_GETARG_BOOL(11);
    const bool newline = PG_GETARG_BOOL(12);

    const text* critics = PG_ARGISNULL(13) ? NULL : PG_GETARG_TEXT_PP(13);
    const text* comment = PG_ARGISNULL(14) ? NULL : PG_GETARG_TEXT_PP(14);

    
    const text* string = (text*)DatumGetPointer(GetAttributeByName(state, "string", &isnull));
    const int32 string_size = VARSIZE_ANY_EXHDR(string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    text* new_string = (text*)palloc0(string_size + value_size + critics_size + comment_size + VARHDRSZ + 500);
    char* s = cun_memcpy(VARDATA(new_string), VARDATA_ANY(string), string_size);


    int changes = 0;
    if(string_size)
    { 
        const bool unknown_reading_old = DatumGetBool(GetAttributeByName(state, "unknown_reading", &isnull));
        const int32 sign_no_old = DatumGetInt32(GetAttributeByName(state, "sign_no", &isnull));
        const int32 word_no_old = DatumGetInt32(GetAttributeByName(state, "word_no", &isnull));
        const int32 compound_no_old = DatumGetInt32(GetAttributeByName(state, "compound_no", &isnull));
        const int32 line_no_old = DatumGetInt32(GetAttributeByName(state, "line_no", &isnull));

        struct States states_old;
        states_old.type = DatumGetObjectId(GetAttributeByName(state, "type", &isnull));
        states_old.phonographic = DatumGetBool(GetAttributeByName(state, "phonographic", &states_old.phonographic_null));
        states_old.alignment = DatumGetObjectId(GetAttributeByName(state, "alignment", &isnull));
        states_old.stem = DatumGetBool(GetAttributeByName(state, "stem", &states_old.stem_null));
        states_old.indicator = DatumGetBool(GetAttributeByName(state, "indicator", &isnull));
        states_old.condition = DatumGetObjectId(GetAttributeByName(state, "condition", &isnull));
        states_old.language = DatumGetObjectId(GetAttributeByName(state, "language", &isnull));

        changes = get_changes(states_old, states, line_no_old != line_no);

        s = close_html(s, changes, states_old);


        // Connectors
        char connector = 0;

        if(inverted)
            connector = ':';
        else if(states_old.indicator && states.indicator && states_old.alignment == states.alignment)
            connector = states_old.phonographic && states.phonographic ? '-' : '.';
        else if(!(states_old.indicator && states_old.alignment == ALIGNMENT_RIGHT) && !(states.indicator && states.alignment == ALIGNMENT_LEFT))
        {       
            if(compound_no_old == compound_no)
                connector = unknown_reading && unknown_reading_old ? '.' : '-';
            else if(line_no_old == line_no)
                connector = ' ';
        }

        if(connector)
            *s++ = connector;
        
        if(sign_no != sign_no_old+1)        // Ellipsis
        {
            s = cun_strcpy(s, "…");
            if(connector)
                *s++ = connector;
        }
        else if (line_no_old != line_no)    // Newline
            s = cun_strcpy(s, "<br>");
    }
    else
        changes = INT_MAX;      

    
    s = open_html(s, changes, states);


    // Actual sign
    //#if(value == "")
    //    s = cun_strcpy(s, "<hr>");
    //else
    if(value)
    {
        const char* ix = cun_index(VARDATA_ANY(value), value_size);
        if(states.type == TYPE_NUMBER || states.type == TYPE_DESCRIPTION || states.type == TYPE_DAMAGE || ix == VARDATA_ANY(value)+value_size) // value is a number or does not have a index
            s = cun_memcpy(s, VARDATA_ANY(value), value_size);
        else
        {
            s = cun_memcpy(s, VARDATA_ANY(value), ix-VARDATA_ANY(value));
            s = cun_strcpy(s, "<span class='cun_index'>");
            s = cun_memcpy(s, ix, VARDATA_ANY(value)+value_size-ix);
            s = cun_strcpy(s, "</span>");
        }
    }

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

    SET_VARSIZE(new_string, s-VARDATA(new_string)+VARHDRSZ);

    bool nulls[13];
    for(int i = 0; i < 13; ++i)
        nulls[i] = false;

    Datum values[13];
    values[0] = PointerGetDatum(new_string);
    values[1] = Int32GetDatum(sign_no);
    values[2] = Int32GetDatum(word_no);
    values[3] = Int32GetDatum(compound_no);
    values[4] = Int32GetDatum(line_no);
    values[5] = ObjectIdGetDatum(states.type);
    values[6] = BoolGetDatum(states.phonographic);
    values[7] = BoolGetDatum(states.indicator);
    values[8] = ObjectIdGetDatum(states.alignment);
    values[9] = BoolGetDatum(states.stem);
    values[10] = ObjectIdGetDatum(states.condition);
    values[11] = ObjectIdGetDatum(states.language);
    values[12] = BoolGetDatum(unknown_reading);

    TupleDesc resultTupleDesc;
    get_call_result_type(fcinfo, NULL, &resultTupleDesc);
    resultTupleDesc = BlessTupleDesc(resultTupleDesc);
    HeapTuple tuple = heap_form_tuple(resultTupleDesc, values, nulls);

    PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum cuneiform_cun_agg_html_finalfunc(PG_FUNCTION_ARGS)
{
    HeapTupleHeader state = PG_GETARG_HEAPTUPLEHEADER(0);
    bool isnull;
    struct States states;
    states.type = DatumGetObjectId(GetAttributeByName(state, "type", &isnull));
    states.phonographic = DatumGetBool(GetAttributeByName(state, "phonographic", &states.phonographic_null));
    states.alignment = DatumGetObjectId(GetAttributeByName(state, "alignment", &isnull));
    states.stem = DatumGetBool(GetAttributeByName(state, "stem", &states.stem_null));
    states.indicator = DatumGetBool(GetAttributeByName(state, "indicator", &isnull));
    states.condition = DatumGetObjectId(GetAttributeByName(state, "condition", &isnull));
    states.language = DatumGetObjectId(GetAttributeByName(state, "language", &isnull));
    const text* string = (text*)DatumGetPointer(GetAttributeByName(state, "string", &isnull));

    text* new_string = (text*)palloc0(VARSIZE_ANY(string)+500);
    char* s = cun_memcpy(VARDATA(new_string), VARDATA_ANY(string), VARSIZE_ANY_EXHDR(string));

    s = close_html(s, INT_MAX, states);

    SET_VARSIZE(new_string, s-VARDATA(new_string)+VARHDRSZ);

    PG_RETURN_TEXT_P(new_string);
}



char* close_code(char* s, int changes, struct States states)
{
    if(states.indicator && (changes & INDICATOR || changes & PHONOGRAPHIC))
    {
        if(states.phonographic & !states.phonographic_null)
            *s++ = '>';
        else 
            *s++ = '}';
    }
    if(changes & TYPE && states.type == TYPE_DESCRIPTION)
        *s++ = '"';
    if(changes & STEM && states.stem && !states.stem_null)
        s = cun_strcpy(s, "⟩");
    if(changes & CONDITION)
    {
        if(states.condition == CONDITION_LOST)
            s = cun_strcpy(s, "]");
        else if(states.condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "⸣");
        else if(states.condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "›");
        else if(states.condition == CONDITION_DELETED)
            s = cun_strcpy(s, "»");
    }
    
    return s;
}

char* open_code(char* s, int changes, struct States states)
{
    if(changes & CONDITION)
    {
        if(states.condition == CONDITION_LOST)
            s = cun_strcpy(s, "[");
        else if(states.condition == CONDITION_DAMAGED)
            s = cun_strcpy(s, "⸢");
        else if(states.condition == CONDITION_INSERTED)
            s = cun_strcpy(s, "‹");
        else if(states.condition == CONDITION_DELETED)
            s = cun_strcpy(s, "«");
    }
    if(changes & STEM && states.stem && !states.stem_null)
        s = cun_strcpy(s, "⟨");
    if(changes & TYPE && states.type == TYPE_DESCRIPTION)
        *s++ = '"';
    if(states.indicator && (changes & INDICATOR || changes & PHONOGRAPHIC))
    {
        if(states.phonographic && !states.phonographic_null)
            *s++ = '<';
        else 
            *s++ = '{';
    }

    return s;
}

Datum cuneiform_cun_agg_sfunc(PG_FUNCTION_ARGS)
{
    bool isnull;

    const HeapTupleHeader state = PG_GETARG_HEAPTUPLEHEADER(0);
    const text* value = PG_ARGISNULL(1) ? NULL : PG_GETARG_TEXT_PP(1);
    const bool unknown_reading = PG_GETARG_BOOL(2);
    const int32 sign_no = PG_GETARG_INT32(3);
    const int32 word_no = PG_GETARG_INT32(4);
    const int32 compound_no = PG_GETARG_INT32(5);
    const int32 line_no = PG_GETARG_INT32(6);

    struct States states;
    const HeapTupleHeader properties = PG_GETARG_HEAPTUPLEHEADER(7);
    states.type = DatumGetObjectId(GetAttributeByName(properties, "type", &isnull));
    states.phonographic = DatumGetBool(GetAttributeByName(properties, "phonographic", &states.phonographic_null));
    states.alignment = DatumGetObjectId(GetAttributeByName(properties, "alignment", &isnull));
    states.indicator = DatumGetBool(GetAttributeByName(properties, "indicator", &isnull));
    states.stem = PG_GETARG_BOOL(8);
    states.stem_null = PG_ARGISNULL(8);
    states.condition = PG_GETARG_OID(9);
    states.language = PG_GETARG_OID(10);

    const bool inverted = PG_GETARG_BOOL(11);
    const bool newline = PG_GETARG_BOOL(12);

    const text* critics = PG_ARGISNULL(13) ? NULL : PG_GETARG_TEXT_PP(13);
    const text* comment = PG_ARGISNULL(14) ? NULL : PG_GETARG_TEXT_PP(14);

    
    const text* string = (text*)DatumGetPointer(GetAttributeByName(state, "string", &isnull));
    const int32 string_size = VARSIZE_ANY_EXHDR(string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const int32 comment_size = comment ? VARSIZE_ANY_EXHDR(comment) : 0;
    text* new_string = (text*)palloc0(string_size + value_size + critics_size + comment_size + VARHDRSZ + 500);
    char* s = cun_memcpy(VARDATA(new_string), VARDATA_ANY(string), string_size);


    int changes = 0;
    if(string_size)
    { 
        const bool unknown_reading_old = DatumGetBool(GetAttributeByName(state, "unknown_reading", &isnull));
        const int32 sign_no_old = DatumGetInt32(GetAttributeByName(state, "sign_no", &isnull));
        const int32 word_no_old = DatumGetInt32(GetAttributeByName(state, "word_no", &isnull));
        const int32 compound_no_old = DatumGetInt32(GetAttributeByName(state, "compound_no", &isnull));
        const int32 line_no_old = DatumGetInt32(GetAttributeByName(state, "line_no", &isnull));

        struct States states_old;
        states_old.type = DatumGetObjectId(GetAttributeByName(state, "type", &isnull));
        states_old.phonographic = DatumGetBool(GetAttributeByName(state, "phonographic", &states_old.phonographic_null));
        states_old.alignment = DatumGetObjectId(GetAttributeByName(state, "alignment", &isnull));
        states_old.stem = DatumGetBool(GetAttributeByName(state, "stem", &states_old.stem_null));
        states_old.indicator = DatumGetBool(GetAttributeByName(state, "indicator", &isnull));
        states_old.condition = DatumGetObjectId(GetAttributeByName(state, "condition", &isnull));
        states_old.language = DatumGetObjectId(GetAttributeByName(state, "language", &isnull));

        changes = get_changes(states_old, states, line_no_old != line_no);

        s = close_code(s, changes, states_old);


        // Connectors
        char connector = 0;

        if(inverted)
            connector = ':';
        else if(states_old.indicator && states.indicator && states_old.alignment == states.alignment)
            connector = states_old.phonographic && states.phonographic ? '-' : '.';
        else if(!(states_old.indicator && states_old.alignment == ALIGNMENT_RIGHT) && !(states.indicator && states.alignment == ALIGNMENT_LEFT))
        {       
            if(compound_no_old == compound_no)
                connector = unknown_reading && unknown_reading_old ? '.' : '-';
            else if(line_no_old == line_no)
                connector = ' ';
        }

        if(connector)
            *s++ = connector;
        
        if(sign_no != sign_no_old+1)        // Ellipsis
        {
            s = cun_strcpy(s, "…");
            if(connector)
                *s++ = connector;
        }
        else if (line_no_old != line_no)    // Newline
            *s++ = '\n';
    }
    else
        changes = INT_MAX;      

    
    s = open_code(s, changes, states);


    // Actual sign
    //#if(value == "")
    //    s = cun_strcpy(s, "<hr>");
    //else
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

    SET_VARSIZE(new_string, s-VARDATA(new_string)+VARHDRSZ);

    bool nulls[13];
    for(int i = 0; i < 13; ++i)
        nulls[i] = false;

    Datum values[13];
    values[0] = PointerGetDatum(new_string);
    values[1] = Int32GetDatum(sign_no);
    values[2] = Int32GetDatum(word_no);
    values[3] = Int32GetDatum(compound_no);
    values[4] = Int32GetDatum(line_no);
    values[5] = ObjectIdGetDatum(states.type);
    values[6] = BoolGetDatum(states.phonographic);
    values[7] = BoolGetDatum(states.indicator);
    values[8] = ObjectIdGetDatum(states.alignment);
    values[9] = BoolGetDatum(states.stem);
    values[10] = ObjectIdGetDatum(states.condition);
    values[11] = ObjectIdGetDatum(states.language);
    values[12] = BoolGetDatum(unknown_reading);

    TupleDesc resultTupleDesc;
    get_call_result_type(fcinfo, NULL, &resultTupleDesc);
    resultTupleDesc = BlessTupleDesc(resultTupleDesc);
    HeapTuple tuple = heap_form_tuple(resultTupleDesc, values, nulls);

    PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum cuneiform_cun_agg_finalfunc(PG_FUNCTION_ARGS)
{
    HeapTupleHeader state = PG_GETARG_HEAPTUPLEHEADER(0);
    bool isnull;
    struct States states;
    states.type = DatumGetObjectId(GetAttributeByName(state, "type", &isnull));
    states.phonographic = DatumGetBool(GetAttributeByName(state, "phonographic", &states.phonographic_null));
    states.alignment = DatumGetObjectId(GetAttributeByName(state, "alignment", &isnull));
    states.stem = DatumGetBool(GetAttributeByName(state, "stem", &states.stem_null));
    states.indicator = DatumGetBool(GetAttributeByName(state, "indicator", &isnull));
    states.condition = DatumGetObjectId(GetAttributeByName(state, "condition", &isnull));
    states.language = DatumGetBool(GetAttributeByName(state, "language", &isnull));
    const text* string = (text*)DatumGetPointer(GetAttributeByName(state, "string", &isnull));

    text* new_string = (text*)palloc0(VARSIZE_ANY(string)+500);
    char* s = cun_memcpy(VARDATA(new_string), VARDATA_ANY(string), VARSIZE_ANY_EXHDR(string));

    s = close_code(s, INT_MAX, states);

    SET_VARSIZE(new_string, s-VARDATA(new_string)+VARHDRSZ);

    PG_RETURN_TEXT_P(new_string);
}

/*Datum cuneiform_cun_agg_sfunc(PG_FUNCTION_ARGS)
{
    HeapTupleHeader t = PG_GETARG_HEAPTUPLEHEADER(0);
    bool isnull;
    const text* string = (text*)DatumGetPointer(GetAttributeByName(t, "string", &isnull));
    const int32 sign_no_old = DatumGetInt32(GetAttributeByName(t, "sign_no", &isnull));
    const int32 word_no_old = DatumGetInt32(GetAttributeByName(t, "word_no", &isnull));
    const int32 line_no_old = DatumGetInt32(GetAttributeByName(t, "line_no", &isnull));
    const Oid type_old = DatumGetObjectId(GetAttributeByName(t, "sign_type", &isnull));
    const Oid condition_old = DatumGetObjectId(GetAttributeByName(t, "condition", &isnull));

    const text* value = PG_GETARG_TEXT_PP(1);
    const int32 sign_no = PG_GETARG_INT32(2);
    const int32 word_no = PG_GETARG_INT32(3);
    const int32 line_no = PG_GETARG_INT32(4);
    const Oid type = PG_GETARG_OID(5);
    const Oid condition = PG_GETARG_OID(6);
    const bool inverted = PG_GETARG_BOOL(7);
    const text* critics = PG_ARGISNULL(8) ? NULL : PG_GETARG_TEXT_PP(8);
    const int32 critics_size = critics ? VARSIZE_ANY_EXHDR(critics) : 0;
    const Oid value_type = PG_GETARG_OID(9);
    const Oid segment_type = PG_GETARG_OID(10);

    const int32 string_size = VARSIZE_ANY_EXHDR(string);
    const int32 value_size = VARSIZE_ANY_EXHDR(value);

    text* new_string = (text*)palloc0(string_size + value_size + VARHDRSZ + 500);

    char* s = cun_memcpy(VARDATA(new_string), VARDATA_ANY(string), string_size);

    if(string_size)
    {   
        if(condition != condition_old || line_no_old != line_no)
            s = cun_close(s, condition_old);

        // Connectors
        if(!(type_old == TYPE_PCP || type_old == TYPE_DETP || type == TYPE_PCS || type == TYPE_DETS))
        {
            if(inverted)
                *s++ = ':';
            else if(word_no_old != word_no)
                *s++ = ' ';
            else
            {
                if(type_old == TYPE_SIGN && type == TYPE_SIGN)
                    *s++ = '.';
                else
                    *s++ = '-';
            }
        }
        else if (((type_old == TYPE_PCP || type_old == TYPE_DETP) && (type == TYPE_PCP || type == TYPE_DETP)) ||
                 ((type_old == TYPE_PCS || type_old == TYPE_DETS) && (type == TYPE_PCS || type == TYPE_DETS)))
            *s++ = '.';

        // Newline
        if(line_no_old != line_no)
            *s++ = '\n';
    }

    if(condition != CON_INTACT)
    {
        if(condition != condition_old || line_no_old != line_no)
        {
            if(condition == CON_GONE)
                *s++ = '[';
            else if(condition == CON_DAMAGED)
                s = cun_strcpy(s, "⸢");
            else if(condition == CON_CORRECTED)
                s = cun_strcpy(s, "‹");
            else if(condition == CON_DELETED)
                s = cun_strcpy(s, "«");
        }
    }

    if(type == TYPE_PCP || type == TYPE_PCS)
        s = cun_strcpy(s, "<");
    else if(type == TYPE_DETP || type == TYPE_DETS)
        s = cun_strcpy(s, "{");
    else if(type == TYPE_DESC)
        s = cun_strcpy(s, "\"");

    // Actual sign
    if(type == TYPE_SPACE)
        s = cun_strcpy(s, "_______");
    else
        s = cun_memcpy(s, VARDATA_ANY(value), value_size);

    if(critics_size)
        s = cun_memcpy(s, VARDATA_ANY(critics), critics_size);

    if(type == TYPE_PCP || type == TYPE_PCS)
        s = cun_strcpy(s, ">");
    else if(type == TYPE_DETP || type == TYPE_DETS)
        s = cun_strcpy(s, "}");
    else if(type == TYPE_DESC)
        s = cun_strcpy(s, "\"");

    SET_VARSIZE(new_string, s-VARDATA(new_string)+VARHDRSZ);

    bool nulls[8];
    nulls[0] = false;
    nulls[1] = false;
    nulls[2] = false;
    nulls[3] = false;
    nulls[4] = false;
    nulls[5] = false;
    nulls[6] = false;
    nulls[7] = false;

    Datum values[8];
    values[0] = PointerGetDatum(new_string);
    values[1] = Int32GetDatum(sign_no);
    values[2] = Int32GetDatum(word_no);
    values[3] = Int32GetDatum(line_no);
    values[4] = ObjectIdGetDatum(type);
    values[5] = ObjectIdGetDatum(condition);
    values[6] = ObjectIdGetDatum(value_type);
    values[7] = ObjectIdGetDatum(segment_type);

    TupleDesc resultTupleDesc;
    get_call_result_type(fcinfo, NULL, &resultTupleDesc);
    resultTupleDesc = BlessTupleDesc(resultTupleDesc);
    HeapTuple tuple = heap_form_tuple(resultTupleDesc, values, nulls);

    PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum cuneiform_cun_agg_finalfunc(PG_FUNCTION_ARGS)
{
    HeapTupleHeader t = PG_GETARG_HEAPTUPLEHEADER(0);
    bool isnull;
    const text* string = (text*)DatumGetPointer(GetAttributeByName(t, "string", &isnull));
    const Oid condition = DatumGetObjectId(GetAttributeByName(t, "condition", &isnull));

    text* new_string = (text*)palloc0(VARSIZE_ANY(string)+5);
    char* s = cun_memcpy(VARDATA(new_string), VARDATA_ANY(string), VARSIZE_ANY_EXHDR(string));

    s = cun_close(s, condition);

    SET_VARSIZE(new_string, s-VARDATA(new_string)+VARHDRSZ);

    PG_RETURN_TEXT_P(new_string);
}*/