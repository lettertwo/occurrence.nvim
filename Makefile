TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/

PLUGIN_FILES := $(shell find plugin -type f -name '*.lua')

LEMMY_HELP := $(shell command -v lemmy-help 2> /dev/null)

.PHONY: lemmy-help
lemmy-help:
ifndef LEMMY_HELP
	cargo install lemmy-help --features=cli
endif

doc/occurrence.txt: lemmy-help $(PLUGIN_FILES)
	@lemmy-help $(PLUGIN_FILES) > $@

.PHONY: doc
doc: doc/occurrence.txt

.PHONY: test
test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"
