#include "cuneiform_print_html.h"

#include "../../print_core/src/cuneiform_print_core.h"

#include <math.h>

#include <fmgr.h>
#include <utils/builtins.h>
#include <access/htup_details.h>
#include <catalog/pg_type.h>
#include <utils/array.h>
#include <tcop/pquery.h>


static void (*set_enums_p)();
static char* (*cun_memcpy_p)(char* s1, const char* s2, size_t n);
static char* (*cun_strcpy_p)(char* s1, const char* s2);
static int (*cun_strcmp_p)(const char* s1, const char* s2);
static void (*cun_capitalize_p)(char* s);

static cunEnumType* (*enum_type)();
static cunEnumCondition* (*enum_condition)();
static cunEnumIndicatorType* (*enum_indicator_type)();
static cunEnumPN* (*enum_pn)();
static cunEnumLanguage* (*enum_language)();

static State* (*init_state)(MemoryContext memcontext);
static int (*get_changes)(const State* s1, const State* s2);

static Connector (*determine_connector)(const State* s1, const State* s2, bool inverted, bool newline, bool ligature);
static Oid (*opened_condition_start)(const char* s, size_t n, bool* no_condition);
static Oid (*opened_condition_end)(const char* s, size_t n);
static void (*copy_compound_comment)(const text* compound_comment, State* state);

void _PG_init(void)
{
    set_enums_p = load_external_function("cuneiform_print_core", "set_enums", true, NULL);
    cun_memcpy_p = load_external_function("cuneiform_print_core", "cun_memcpy", true, NULL);
    cun_strcpy_p = load_external_function("cuneiform_print_core", "cun_strcpy", true, NULL);
    cun_strcmp_p = load_external_function("cuneiform_print_core", "cun_strcmp", true, NULL);
    cun_capitalize_p = load_external_function("cuneiform_print_core", "cun_capitalize", true, NULL);

    enum_type = load_external_function("cuneiform_print_core", "cun_enum_type", true, NULL);
    enum_condition = load_external_function("cuneiform_print_core", "cun_enum_condition", true, NULL);
    enum_indicator_type = load_external_function("cuneiform_print_core", "cun_enum_indicator_type", true, NULL);
    enum_pn = load_external_function("cuneiform_print_core", "cun_enum_pn", true, NULL);
    enum_language = load_external_function("cuneiform_print_core", "cun_enum_language", true, NULL);

    init_state = load_external_function("cuneiform_print_core", "cun_init_state", true, NULL);
    get_changes = load_external_function("cuneiform_print_core", "cun_get_changes", true, NULL);
    determine_connector = load_external_function("cuneiform_print_core", "cun_determine_connector", true, NULL);
    opened_condition_start = load_external_function("cuneiform_print_core", "cun_opened_condition_start", true, NULL);
    opened_condition_end = load_external_function("cuneiform_print_core", "cun_opened_condition_end", true, NULL);
    copy_compound_comment = load_external_function("cuneiform_print_core", "cun_copy_compound_comment", true, NULL);
};

#define set_enums set_enums_p
#define cun_memcpy cun_memcpy_p
#define cun_strcpy cun_strcpy_p
#define cun_strcmp cun_strcmp_p
#define cun_capitalize cun_capitalize_p

#define EXP_LINE_SIZE_HTML 1000
#define MAX_EXTRA_SIZE_HTML 200

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


// HTML

static char* open_html(char* s, int changes, const State* state)
{
    if(changes >= LANGUAGE && state->language != enum_language()->sumerian)
    {
        if(state->language == enum_language()->akkadian)
            s = cun_strcpy(s, "<span class='akkadian'>");
        else if(state->language == enum_language()->hittite)
            s = cun_strcpy(s, "<span class='hittite'>");
        else if(state->language == enum_language()->eblaite)
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
        if(state->phonographic && state->language == enum_language()->sumerian)
            s = cun_strcpy(s, "<span class='phonographic'>");
        else if(!state->phonographic && state->language != enum_language()->sumerian)
            s = cun_strcpy(s, "<span class='logographic'>");
    }
    if(changes >= TYPE && (state->type != enum_type()->value || state->unknown_reading)  && state->type != enum_type()->punctuation)
    {
        if(state->type == enum_type()->number)
            s = cun_strcpy(s, "<span class='number'>");
        else if(state->type == enum_type()->description)
            s = cun_strcpy(s, "<span class='description'>");
        else if(state->type == enum_type()->damage)
            s = cun_strcpy(s, "<span class='damage'>");
        else if(state->unknown_reading)
            s = cun_strcpy(s, "<span class='unknown_reading'>");
    }
    if(changes >= INDICATOR && state->indicator_type != enum_indicator_type()->none)
        s = cun_strcpy(s, "<span class='indicator'>");
    if(changes >= CONDITION && state->condition != enum_condition()->intact)
    {
        if(state->condition == enum_condition()->lost)
            s = cun_strcpy(s, "<span class='lost'>");
        else if(state->condition == enum_condition()->damaged)
            s = cun_strcpy(s, "<span class='damaged'>");
        else if(state->condition == enum_condition()->inserted)
            s = cun_strcpy(s, "<span class='inserted'>");
        else if(state->condition == enum_condition()->deleted)
            s = cun_strcpy(s, "<span class='deleted'>");
        else if(state->condition == enum_condition()->erased)
            s = cun_strcpy(s, "<span class='erased'>");
    }
    return s;
}

static char* close_html(char* s, int changes, const State* state)
{
    if(changes >= CONDITION && state->condition != enum_condition()->intact)
        s = cun_strcpy(s, "</span>");
    if(changes >= INDICATOR && state->indicator_type != enum_indicator_type()->none)
        s = cun_strcpy(s, "</span>");
    if(changes >= TYPE && (state->type != enum_type()->value || state->unknown_reading) && state->type != enum_type()->punctuation)
        s = cun_strcpy(s, "</span>");
    if(changes >= PHONOGRAPHIC && !state->phonographic_null && (state->phonographic == (state->language == enum_language()->sumerian)))
        s = cun_strcpy(s, "</span>");
    if(changes >= HIGHLIGHT && state->highlight)
        s = cun_strcpy(s, "</span>");
    if(changes >= STEM && state->stem && !state->stem_null)
        s = cun_strcpy(s, "</span>");
    if(changes >= LANGUAGE && state->language != enum_language()->sumerian)
        s = cun_strcpy(s, "</span>");
    return s;
}


static char* open_condition_html(char* s, Oid condition)
{
    if(condition == enum_condition()->lost)
        s = cun_strcpy(s, "<span class='open-lost'></span>");
    else if(condition == enum_condition()->damaged)
        s = cun_strcpy(s, "<span class='open-damaged'></span>");
    else if(condition == enum_condition()->inserted)
        s = cun_strcpy(s, "<span class='open-inserted'></span>");
    else if(condition == enum_condition()->deleted)
        s = cun_strcpy(s, "<span class='open-deleted'></span>");
    else if(condition == enum_condition()->erased)
        s = cun_strcpy(s, "<span class='open-erased'></span>");
    return s;
}

static char* close_condition_html(char* s, Oid condition)
{
    if(condition == enum_condition()->lost)
        s = cun_strcpy(s, "<span class='close-lost'></span>");
    else if(condition == enum_condition()->damaged)
        s = cun_strcpy(s, "<span class='close-damaged'></span>");
    else if(condition == enum_condition()->inserted)
        s = cun_strcpy(s, "<span class='close-inserted'></span>");
    else if(condition == enum_condition()->deleted)
        s = cun_strcpy(s, "<span class='close-deleted'></span>");
    else if(condition == enum_condition()->erased)
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

    if(PG_ARGISNULL(0))
        state = init_state(aggcontext);
    else
        state = (State*) PG_GETARG_POINTER(0);

    state_old = *state;

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

    state->capitalize = state_old.capitalize || (PG_GETARG_BOOL(ARG_CAPITALIZED) && state_old.word_no != state->word_no);

    state->unknown_reading = state->type == enum_type()->sign;

    const text* value = PG_ARGISNULL(ARG_VALUE) ? NULL : PG_GETARG_TEXT_PP(ARG_VALUE);
    const text* sign = PG_ARGISNULL(ARG_SIGN) ? NULL : PG_GETARG_TEXT_PP(ARG_SIGN);

    const bool inverted = PG_GETARG_BOOL(ARG_INVERTED);
    const bool newline = PG_GETARG_BOOL(ARG_NEWLINE);
    const bool ligature = PG_GETARG_BOOL(ARG_LIGATURE);

    const text* critics = PG_ARGISNULL(ARG_CRITICS) ? NULL : PG_GETARG_TEXT_PP(ARG_CRITICS);
    const text* comment = PG_ARGISNULL(ARG_COMMENT) ? NULL : PG_GETARG_TEXT_PP(ARG_COMMENT);
    const text* compound_comment = PG_ARGISNULL(ARG_COMPOUND_COMMENT) ? NULL : PG_GETARG_TEXT_PP(ARG_COMPOUND_COMMENT);

    const text* section = PG_ARGISNULL(ARG_SECTION) ? NULL : PG_GETARG_TEXT_PP(ARG_SECTION);

    const int32 string_size = VARSIZE_ANY_EXHDR(state->string);
    const int32 value_size = value ? VARSIZE_ANY_EXHDR(value) : 0;
    const int32 value_size_final = calculate_value_size_replacing_conditions_html(value ? VARDATA_ANY(value) : NULL, value_size);
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

    char* s = VARDATA(state->string)+string_size;

    bool no_condition;
    const Oid inner_condition = opened_condition_start(value ? (char*)VARDATA_ANY(value) : NULL, value_size, &no_condition);
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

    if(value)
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
            s = write_value_replacing_conditions_html(s, VARDATA_ANY(value), value_size);
            if(state->capitalize && state->indicator_type == enum_indicator_type()->none) {
                cun_capitalize(s_);
                state->capitalize = false;
            }
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

    copy_compound_comment(compound_comment, state);

    if(!no_condition)
        state->condition = opened_condition_end(value ? (char*)VARDATA_ANY(value) : NULL, value_size);

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