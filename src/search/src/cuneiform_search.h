#include <postgres.h>

#include <funcapi.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

Datum position_in(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_in);

Datum position_out(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_out);

Datum position_recv(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_recv);

Datum position_send(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_send);


Datum position_less(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_less);

Datum position_greater(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_greater);

Datum position_leq(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_leq);

Datum position_geq(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_geq);

Datum position_equal(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_equal);

Datum position_neq(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_neq);


Datum position_next(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_next);


Datum position_order(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_order);

Datum position_equalimage(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_equalimage);

Datum position_hash(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_hash);

Datum position_hash_extended(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_hash_extended);


Datum position_sign_no(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_sign_no);

Datum position_component_no(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_component_no);

Datum position_construct(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(position_construct);


Datum unique(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(unique);

Datum consecutive(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(consecutive);

Datum get_sign_nos(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(get_sign_nos);