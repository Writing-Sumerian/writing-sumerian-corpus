#include <postgres.h>

#include <funcapi.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

void _PG_init(void);

Datum cuneiform_cun_agg_html_sfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_cun_agg_html_sfunc);

Datum cuneiform_cun_agg_html_finalfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_cun_agg_html_finalfunc);