all:
	make -C data/signlist
	make -C data/context
	make -C data/database
	make -C data/log
	make -C modules/sign_properties
	make -C modules/create_corpus
	make -C modules/actions
	make -C modules/citation
	make -C modules/composer
	make -C modules/encoder
	make -C modules/parser
	make -C modules/editor
	make -C modules/search
	make -C corpus/encode_corpus
	make -C corpus/parse_corpus
	make -C corpus/replace
	make -C corpus/search_corpus
	make -C loader
	make -C test

install:
	make -C data/signlist install
	make -C data/context install
	make -C data/database install
	make -C data/log install
	make -C modules/sign_properties install
	make -C modules/create_corpus install
	make -C modules/actions install
	make -C modules/citation install
	make -C modules/composer install
	make -C modules/encoder install
	make -C modules/parser install
	make -C modules/editor install
	make -C modules/search install
	make -C corpus/encode_corpus install
	make -C corpus/parse_corpus install
	make -C corpus/replace install
	make -C corpus/search_corpus install
	make -C loader install
	make -C test install