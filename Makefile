PROJECT_NAME := occurrence.nvim
NVIM_VERSION := 0.10.0

./lua_modules/bin/%:
	@mkdir -p $(@D)
	@luarocks install $*

./vendor/panvimdoc/panvimdoc.sh:
	@mkdir -p $(@D)
	@git clone git@github.com:kdheepak/panvimdoc.git $(@D)

./doc/%.txt: ./vendor/panvimdoc/panvimdoc.sh README.md
	@mkdir -p $(@D)
	@$< --project-name "$*" --input-file "$(word 2,$^)" --vim-version "NVIM >= $(NVIM_VERSION)"

./doc/tags:
	@mkdir -p $(@D)
	@printf "%s\n" "Generating help tags in $(@D)"
	@printf "%s\n" "nvim --headless -c 'helptags $(@D)' -c q"
	@nvim --headless -c "helptags $(@D)" -c q

.PHONY: doc
doc: ./doc/$(PROJECT_NAME).txt ./doc/tags

# Allow passing arguments after target name
%:
	@:

.PHONY: test
test: ./lua_modules/bin/busted ./lua_modules/bin/nlua
	@printf "%s\n" "LUA_PATH='lua_modules/share/lua/5.1/?.lua;lua_modules/share/lua/5.1/?/init.lua;;' LUA_CPATH='lua_modules/lib/lua/5.1/?.so;;' $< --lua $(word 2,$^) --exclude-pattern=perf_* $(or $(filter-out $@,$(MAKECMDGOALS)),tests/)"
	@LUA_PATH='lua_modules/share/lua/5.1/?.lua;lua_modules/share/lua/5.1/?/init.lua;;' LUA_CPATH='lua_modules/lib/lua/5.1/?.so;;' $< --lua $(word 2,$^) --exclude-pattern=perf_* $(or $(filter-out $@,$(MAKECMDGOALS)),tests/)

.PHONY: test-perf
test-perf: ./lua_modules/bin/busted ./lua_modules/bin/nlua
	@printf "%s\n" "$< --lua $(word 2,$^) tests/perf_*"
	@$< --lua $(word 2,$^) tests/perf_*

.PHONY: test-all
test-all: test test-perf
