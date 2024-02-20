EXTENSION    		:= cuneiform_corpus_statistics

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

build/$(EXTENSION)--$(version).sql: sql/transliterations.sql sql/signs_count.sql sql/signs_present.sql
	@mkdir -p build
	@cat sql/transliterations.sql sql/signs_count.sql sql/signs_present.sql > build/$(EXTENSION)--$(version).sql