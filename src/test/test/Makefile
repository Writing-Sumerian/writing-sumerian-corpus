EXTENSION    		:= cuneiform_test

version      		:= $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\\([^']*\\)'/\\1/")
modules      		:= $(patsubst %.c,%,$(wildcard src/*.c))
tests        		:= $(wildcard test/sql/*.sql)
docs         		:= $(wildcard doc/*.md)
sql         		:= $(sort $(wildcard sql/*.sql))

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

build/$(EXTENSION)--$(version).sql: $(sql)
	@mkdir -p build
	@cat $(sql) > build/$(EXTENSION)--$(version).sql