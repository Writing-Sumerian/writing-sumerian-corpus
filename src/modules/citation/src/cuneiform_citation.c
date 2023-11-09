#include "cuneiform_citation.h"

#include <math.h>

#include <fmgr.h>
#include <executor/executor.h>
#include <executor/spi.h>
#include <utils/builtins.h>
#include <access/htup_details.h>
#include <catalog/pg_type.h>
#include <utils/array.h>

int32 dash_size = strlen("–");
int32 dot_size = strlen("; ");

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


text* copy_text(const text* b, MemoryContext memcontext)
{
    if(!b)
        return NULL;
    text* a = (text*) MemoryContextAllocZero(memcontext, VARSIZE_ANY_EXHDR(b)+VARHDRSZ);
    SET_VARSIZE(a, VARSIZE_ANY_EXHDR(b)+VARHDRSZ);
    memcpy((void*)VARDATA(a), (void*)VARDATA_ANY(b), VARSIZE_ANY_EXHDR(b));
    return a;
}

typedef struct State
{
    text* string;

    text* surface;
    text* surface_start;
    int32 surface_no;
    int32 surface_no_start;
    bool print_surface;

    text* block;
    text* block_start;
    int32 block_no;
    int32 block_no_start;
    bool print_block;

    text* line;
    text* line_start;
    int32 line_no;
    int32 line_no_start;
} State;


text* assamble_range(const State* state, text* string)
{
    const int32 string_size = VARSIZE_ANY_EXHDR(string);
    int32 size = string_size;

    if(string_size)
        size += dot_size;

    const int changes 
        = 4 * (int)(state->surface_no != state->surface_no_start) 
        + 2 * (int)(state->block_no != state->block_no_start)
        + (int)(state->line_no != state->line_no_start);

    if(changes > 3)
        size += VARSIZE_ANY_EXHDR(state->surface_start) + VARSIZE_ANY_EXHDR(state->surface) + 2;
    else if(state->print_surface)
        size += VARSIZE_ANY_EXHDR(state->surface_start) + 1;
    if(changes > 1)
        size += VARSIZE_ANY_EXHDR(state->block_start) + VARSIZE_ANY_EXHDR(state->block) + 4;
    else if(state->print_block)
        size += VARSIZE_ANY_EXHDR(state->block_start) + 1;
    size += VARSIZE_ANY_EXHDR(state->line_start);
    if(changes > 0)
        size += VARSIZE_ANY_EXHDR(state->line);

     
    string = (text*)repalloc(string, string_size + VARHDRSZ +1000);
    char* s = VARDATA(string)+string_size;

    
    if(string_size)
        s = cun_strcpy(s, "; ");

    if((changes > 3 || state->print_surface) && state->surface_start)
    {
        s = cun_memcpy(s, VARDATA(state->surface_start), VARSIZE_ANY_EXHDR(state->surface_start));
        s = cun_strcpy(s, " ");
    }
    if((changes > 1 || state->print_block) && state->block_start)
    {
        s = cun_memcpy(s, VARDATA(state->block_start), VARSIZE_ANY_EXHDR(state->block_start));
        s = cun_strcpy(s, " ");
    }
    if(state->line_start)
        s = cun_memcpy(s, VARDATA(state->line_start), VARSIZE_ANY_EXHDR(state->line_start));
    if(changes > 1)
        s = cun_strcpy(s, " – ");
    else if(changes > 0)
        s = cun_strcpy(s, "–");
    if(changes > 3 && state->surface)
    {
        s = cun_memcpy(s, VARDATA(state->surface), VARSIZE_ANY_EXHDR(state->surface));
        s = cun_strcpy(s, " ");
    }
    if(changes > 1 && state->block)
    {
        s = cun_memcpy(s, VARDATA(state->block), VARSIZE_ANY_EXHDR(state->block));
        s = cun_strcpy(s, " ");
    }
    if(changes > 0 && state->line)
        s = cun_memcpy(s, VARDATA(state->line), VARSIZE_ANY_EXHDR(state->line));
    
    SET_VARSIZE(string, s-VARDATA(string)+VARHDRSZ);

    return string;
}


Datum cuneiform_citation_agg_sfunc(PG_FUNCTION_ARGS)
{
    MemoryContext aggcontext;
    State* state;

    if (!AggCheckCallContext(fcinfo, &aggcontext))
    {
        /* cannot be called directly because of internal-type argument */
        elog(ERROR, "array_agg_transfn called in non-aggregate context");
    }

    if(PG_ARGISNULL(0)) 
    {
        state = (State*) MemoryContextAllocZero(aggcontext, sizeof(State));
        state->string = (text*) MemoryContextAllocZero(aggcontext, VARHDRSZ);
        SET_VARSIZE(state->string, VARHDRSZ);
        state->surface_no = -2;
        state->block_no = -2;
        state->line_no = -2;
        state->surface_no_start = -2;
        state->block_no_start = -2;
        state->line_no_start = -2;
        state->print_surface = true;
        state->print_block = true;
    }
    else
        state = (State*) PG_GETARG_POINTER(0);

    const text* surface = PG_ARGISNULL(1) ? NULL : PG_GETARG_TEXT_PP(1);
    const int32 surface_no = PG_GETARG_INT32(2);
    const text* block = PG_ARGISNULL(3) ? NULL : PG_GETARG_TEXT_PP(3);
    const int32 block_no = PG_GETARG_INT32(4);
    const text* line = PG_ARGISNULL(5) ? NULL : PG_GETARG_TEXT_PP(5);
    const int32 line_no = PG_GETARG_INT32(6);

    if(line_no != state->line_no+1)
    {
        if(!PG_ARGISNULL(0)) 
            state->string = assamble_range(state, state->string);

        state->print_surface = false;
        state->print_block = false;

        if(surface_no != state->surface_no_start)
        {
            state->surface_start = copy_text(surface, aggcontext);
            state->surface_no_start = surface_no;
            state->print_surface = true;
            state->print_block = true;
        }
        if(block_no != state->block_no_start)
        {
            state->block_start = copy_text(block, aggcontext);
            state->block_no_start = block_no;
            state->print_block = true;
        }
        state->line_start = copy_text(line, aggcontext);
        state->line_no_start = line_no;
    }

    if(surface_no != state->surface_no)
    {
        state->surface = copy_text(surface, aggcontext);
        state->surface_no = surface_no;
        state->print_surface = true;
        state->print_block = true;
    }
    if(block_no != state->block_no)
    {
        state->block = copy_text(block, aggcontext);
        state->block_no = block_no;
        state->print_block = true;
    }
    state->line = copy_text(line, aggcontext);
    state->line_no = line_no;

    PG_RETURN_POINTER(state);
}

Datum cuneiform_citation_agg_finalfunc(PG_FUNCTION_ARGS)
{
    MemoryContext aggcontext;
    if (!AggCheckCallContext(fcinfo, &aggcontext))
    {
        /* cannot be called directly because of internal-type argument */
        elog(ERROR, "array_agg_transfn called in non-aggregate context");
    }

    const State* state = PG_ARGISNULL(0) ? NULL : (State*) PG_GETARG_POINTER(0);
    if(state == NULL)
        PG_RETURN_NULL();

    // the finalfunc may not alter state, therefore we need to copy everything

    text* string = copy_text(state->string, aggcontext);
    string = assamble_range(state, string);

    PG_RETURN_TEXT_P(string);
}