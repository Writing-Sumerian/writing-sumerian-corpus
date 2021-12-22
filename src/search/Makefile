EXTENSION    		:= cuneiform_search

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

build/$(EXTENSION)--$(version).sql: build/$(EXTENSION)_comp.py sql/$(EXTENSION).sql
	@mkdir -p build
	@py2plpy build/$(EXTENSION)_comp.py build/$(EXTENSION)--$(version).sql
	@cat sql/$(EXTENSION).sql >> build/$(EXTENSION)--$(version).sql

build/$(EXTENSION)_comp.py: python/$(EXTENSION).py python/grammar.lark
	@mkdir -p build
	@csplit -n 1 --suppress-matched --elide-empty-files -f build/$(EXTENSION) python/$(EXTENSION).py /{{grammar}}/ {*}
	@cat build/$(EXTENSION)0 python/grammar.lark build/$(EXTENSION)1 > build/$(EXTENSION)_comp.py