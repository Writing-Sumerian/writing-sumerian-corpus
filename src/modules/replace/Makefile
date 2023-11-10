EXTENSION    		:= cuneiform_replace

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

sql					:= sql/aggregates.sql sql/data_structures.sql sql/corpus_replace.sql sql/words_replace.sql sql/compounds_replace.sql


all: build/$(EXTENSION)--$(version).sql

build/$(EXTENSION)--$(version).sql:  python/parse.py $(sql)
	@mkdir -p build
	@py2plpy python/parse.py build/$(EXTENSION)--$(version).sql
	@cat $(sql) >> build/$(EXTENSION)--$(version).sql