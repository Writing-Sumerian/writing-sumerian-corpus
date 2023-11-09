EXTENSION    		:= cuneiform_composer

version      		:= $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\\([^']*\\)'/\\1/")
modules      		:= $(patsubst %.c,%,$(wildcard src/*.c))
tests        		:= $(wildcard test/sql/*.sql)
docs         		:= $(wildcard doc/*.md)

DATA         		:= build/$(EXTENSION)--$(version).sql
PG_CONFIG    		:= pg_config
EXTRA_CLEAN  		:= build/$(EXTENSION)--$(version).sql
PGXS 				:= $(shell $(PG_CONFIG) --pgxs)
ifneq ($(tests),)
	TESTS        	:= $(tests)
	REGRESS      	:= $(patsubst test/sql/%.sql,%,$(TESTS))
	REGRESS_OPTS 	:= --inputdir=test
endif
ifneq ($(docs),)
	DOCS     		:= $(docs)
endif
ifneq ($(modules),)
	MODULES			:= $(modules)
endif

include $(PGXS)

all: build/$(EXTENSION)--$(version).sql

sql					:= sql/aggregates.sql sql/signlist.sql sql/views.sql

build/$(EXTENSION)--$(version).sql:  python/compose_sign.py $(sql)
	@mkdir -p build
	@py2plpy python/compose_sign.py build/$(EXTENSION)--$(version).sql
	@cat $(sql) >> build/$(EXTENSION)--$(version).sql