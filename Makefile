TEST_TIMEOUT = 2000
TEST_REPORTER = spec

lib/simple-proxy.js: src/simple-proxy.ls
	@livescript -c -o lib src

test: lib/simple-proxy.js
	@NODE_ENV=test \
		node_modules/.bin/mocha \
			--timeout $(TEST_TIMEOUT) \
			--reporter $(TEST_REPORTER) \
			--compilers coffee:coffee-script \
			test/*.coffee

.PHONY: test lib/simple-proxy.js
