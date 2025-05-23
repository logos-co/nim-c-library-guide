# Makefile for the Go Bindings Clock example
#
# IMPLEMENTATION STEPS:
# 1. Change name and assignment of `EXAMPLE_LIB_REPO` for a name and url to your library
# 2. Change name and assignment of `EXAMPLE_LIB_DIR` for a name and path of your library
# 3. Rename all `clock` instances to your library's name

# Directories
THIRD_PARTY_DIR := ../third_party
# TODO: rename and set your library's url
EXAMPLE_LIB_REPO := https://github.com/status-im/nim-c-library-guide
# TODO: rename and set your library's path
EXAMPLE_LIB_DIR := $(THIRD_PARTY_DIR)/nim-c-library-guide

.PHONY: all clean prepare build-libclock build

# Default target
all: build

# Prepare third_party directory and clone the example library
# TODO: remove the "git checkout feat-initial-version" part
prepare:
	@echo "Creating third_party directory..."
	@mkdir -p $(THIRD_PARTY_DIR)

	@echo "Cloning example library repository..."
	@if [ ! -d "$(EXAMPLE_LIB_DIR)" ]; then \
		cd $(THIRD_PARTY_DIR) && \
		git clone $(EXAMPLE_LIB_REPO) && \
		cd $(EXAMPLE_LIB_DIR) && \
		git checkout feat-initial-version; \
		make update; \
	else \
		echo "example library repository already exists."; \
	fi

# Build libclock
build-libclock: prepare
	@echo "Building libclock..."
	@cd $(EXAMPLE_LIB_DIR) && make libclock

# Build Example Go Bindings
build: build-libclock
	@echo "Building Example Go Bindings..."
	go build ./...

# Clean up generated files
clean:
	@echo "Cleaning up..."
	@rm -rf $(THIRD_PARTY_DIR)
	@rm -f go-bindings-template