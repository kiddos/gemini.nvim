TESTS_INIT=tests/init.lua
TESTS_DIR=tests/

all:
	cmake -B build
	make -C build -j

clean:
	rm -rf build
	rm -rf lua/gemini/*.so


test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"


.PHONY: all clean test
