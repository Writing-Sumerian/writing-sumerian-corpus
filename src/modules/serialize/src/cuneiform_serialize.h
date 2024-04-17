#include <postgres.h>

#include <funcapi.h>

void _PG_init(void);

Datum cuneiform_cun_agg_sfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_cun_agg_sfunc);

Datum cuneiform_cun_agg_finalfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_cun_agg_finalfunc);

Datum cuneiform_cun_agg_html_sfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_cun_agg_html_sfunc);

Datum cuneiform_cun_agg_html_finalfunc(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(cuneiform_cun_agg_html_finalfunc);