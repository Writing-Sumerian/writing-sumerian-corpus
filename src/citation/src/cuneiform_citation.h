#include <postgres.h>

#include <funcapi.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

Datum cuneiform_citation_agg_sfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_citation_agg_sfunc);

Datum cuneiform_citation_agg_finalfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_citation_agg_finalfunc);