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

build/$(EXTENSION)--$(version).sql: build/preparse_search.py build/parse_search.py sql/$(EXTENSION).sql
	@mkdir -p build
	@py2plpy build/preparse_search.py build/preparse_search.sql
	@py2plpy build/parse_search.py build/parse_search.sql
	@cat build/preparse_search.sql build/parse_search.sql sql/$(EXTENSION).sql > build/$(EXTENSION)--$(version).sql

build/preparse_search.py: python/preparse_search.py python/grammar_pre.lark
	@mkdir -p build
	@csplit -n 1 -s --suppress-matched --elide-empty-files -f build/$(EXTENSION) python/preparse_search.py /{{grammar}}/ {*}
	@cat build/$(EXTENSION)0 python/grammar_pre.lark build/$(EXTENSION)1 > build/preparse_search.py

build/parse_search.py: python/parse_search.py python/grammar.lark
	@mkdir -p build
	@csplit -n 1 -s --suppress-matched --elide-empty-files -f build/$(EXTENSION) python/parse_search.py /{{grammar}}/ {*}
	@cat build/$(EXTENSION)0 python/grammar.lark build/$(EXTENSION)1 > build/parse_search.py