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

static State* (*init_state)(FunctionCallInfo fcinfo, MemoryContext memcontext, State* state_old);
static int (*get_changes)(const State* s1, const State* s2);

static Connector (*determine_connector)(const State* s1, const State* s2, bool inverted, bool newline, bool ligature);
static Oid (*opened_condition_start)(const char* s, size_t n, bool* no_condition);
static Oid (*opened_condition_end)(const char* s, size_t n);

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
};

#define set_enums set_enums_p
#define cun_memcpy cun_memcpy_p
#define cun_strcpy cun_strcpy_p
#define cun_strcmp cun_strcmp_p
#define cun_capitalize cun_capitalize_p

#define EXP_LINE_SIZE_HTML 1000
#define MAX_EXTRA_SIZE_HTML 200


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

    state = init_state(fcinfo, aggcontext, &state_old);

    const text* value = PG_ARGISNULL(ARG_VALUE) ? NULL : PG_GETARG_TEXT_PP(ARG_VALUE);
    const text* sign = PG_ARGISNULL(ARG_SIGN) ? NULL : PG_GETARG_TEXT_PP(ARG_SIGN);

    const bool inverted = PG_GETARG_BOOL(ARG_INVERTED);
    const bool newline = PG_GETARG_BOOL(ARG_NEWLINE);
    const bool ligature = PG_GETARG_BOOL(ARG_LIGATURE);

    const text* critics = PG_ARGISNULL(ARG_CRITICS) ? NULL : PG_GETARG_TEXT_PP(ARG_CRITICS);
    const text* comment = PG_ARGISNULL(ARG_COMMENT) ? NULL : PG_GETARG_TEXT_PP(ARG_COMMENT);

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



// Code

static char* open_code(char* s, const State* s1, State* s2)
{
    if((s1 != NULL && s1->language != s2->language) || (s1 == NULL && s2->language != enum_language()->sumerian))
    {
        if(s2->language == enum_language()->akkadian)
            s = cun_strcpy(s, "%a ");
        else if(s2->language == enum_language()->eblaite)
            s = cun_strcpy(s, "%e ");
        else if(s2->language == enum_language()->hittite)
            s = cun_strcpy(s, "%h ");
        else if(s2->language == enum_language()->sumerian)
            s = cun_strcpy(s, "%s ");
    }
    if(!s2->pn_type_null && (s1 == NULL || s1->pn_type != s2->pn_type || s2->pn_type_null || s1->compound_no != s2->compound_no))
    {
        if(s2->pn_type == enum_pn()->person)
            s = cun_strcpy(s, "%person ");
        else if(s2->pn_type == enum_pn()->god)
            s = cun_strcpy(s, "%god ");
        else if(s2->pn_type == enum_pn()->place)
            s = cun_strcpy(s, "%place ");
        else if(s2->pn_type == enum_pn()->water)
            s = cun_strcpy(s, "%water ");
        else if(s2->pn_type == enum_pn()->field)
            s = cun_strcpy(s, "%field ");
        else if(s2->pn_type == enum_pn()->temple)
            s = cun_strcpy(s, "%temple ");
        else if(s2->pn_type == enum_pn()->month)
            s = cun_strcpy(s, "%month ");
        else if(s2->pn_type == enum_pn()->object)
            s = cun_strcpy(s, "%object ");
        else if(s2->pn_type == enum_pn()->ethnicity)
            s = cun_strcpy(s, "%ethnicity ");
    }

    if(s1 != NULL && !s1->stem && s2->stem && !s1->stem_null && !s2->stem_null && s1->word_no == s2->word_no)
        *s++ = ';';

    if(!s2->phonographic_null && !s2->phonographic && s2->indicator_type == enum_indicator_type()->none && (s1 == NULL || s1->phonographic_null || s1->phonographic || s1->indicator_type != enum_indicator_type()->none || s1->line_no != s2->line_no))
        *s++ = '_';

    if(s1 == NULL || s1->condition != s2->condition || s1->line_no != s2->line_no)
    {
        if(s2->condition == enum_condition()->lost)
            s = cun_strcpy(s, "[");
        else if(s2->condition == enum_condition()->damaged)
            s = cun_strcpy(s, "⸢");
        else if(s2->condition == enum_condition()->inserted)
            s = cun_strcpy(s, "‹");
        else if(s2->condition == enum_condition()->deleted)
            s = cun_strcpy(s, "«");
    }

    if(s2->capitalize) {
        *s++ = '&';
        s2->capitalize = false;
    }

    if(s2->indicator_type != enum_indicator_type()->none && (s1 == NULL || s1->indicator_type != s2->indicator_type || s1->phonographic != s2->phonographic || s1->phonographic_null || s1->line_no != s2->line_no))
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
    if(s1->indicator_type != enum_indicator_type()->none && (s2 == NULL || s1->indicator_type != s2->indicator_type || s1->phonographic != s2->phonographic || s2->phonographic_null || s1->line_no != s2->line_no))
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
        if(s1->condition == enum_condition()->lost)
            s = cun_strcpy(s, "]");
        else if(s1->condition == enum_condition()->damaged)
            s = cun_strcpy(s, "⸣");
        else if(s1->condition == enum_condition()->inserted)
            s = cun_strcpy(s, "›");
        else if(s1->condition == enum_condition()->deleted)
            s = cun_strcpy(s, "»");
    }

    if(!s1->phonographic_null && !s1->phonographic && s1->indicator_type == enum_indicator_type()->none && (s2 == NULL || s2->phonographic_null || s2->phonographic || s2->indicator_type != enum_indicator_type()->none || s1->line_no != s2->line_no))
        *s++ = '_';

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
        if(c.connector == SEP_WORD)
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