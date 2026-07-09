SHELL := /usr/bin/env bash

TARGET := armv7-unknown-linux-gnueabihf
RM2_SSH ?= root@10.11.99.1
RM2_APPLOAD_DIR ?= /home/root/xovi/exthome/appload

UNAME_S := $(shell uname -s)
HAS_ARM_GCC := $(shell command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1 && echo yes || true)
HAS_ZIGBUILD := $(shell command -v cargo-zigbuild >/dev/null 2>&1 && echo yes || true)

.PHONY: help setup-rm2 setup-appload-rm2 test build-rm2-qtfb bundle-rm2-qtfb install-rm2-qtfb smoke-rm2-hardware clean

help:
	@echo "Targets:"
	@echo "  make setup-rm2                         Install Rust target and host build helpers"
	@echo "  make setup-appload-rm2 RM2_SSH=root@10.11.99.1"
	@echo "  make test                              Run native tests"
	@echo "  make build-rm2-qtfb                    Cross-build riddle for reMarkable 2"
	@echo "  make bundle-rm2-qtfb                   Stage dist/riddle-rm2"
	@echo "  make install-rm2-qtfb RM2_SSH=root@10.11.99.1"
	@echo "  make smoke-rm2-hardware RM2_SSH=root@10.11.99.1"
	@echo ""
	@echo "macOS uses Zig via cargo-zigbuild. Linux prefers arm-linux-gnueabihf-gcc."

setup-rm2:
	@if ! command -v cargo >/dev/null 2>&1; then \
		if ! command -v curl >/dev/null 2>&1; then \
			echo "missing curl; install curl first" >&2; exit 1; \
		fi; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
			| sh -s -- -y --profile minimal --default-toolchain stable; \
		. "$$HOME/.cargo/env"; \
	fi
	@rustup target add $(TARGET)
	@rustup component add rustfmt
ifeq ($(UNAME_S),Darwin)
	@if ! command -v zig >/dev/null 2>&1; then \
		if command -v brew >/dev/null 2>&1; then \
			brew install zig; \
		else \
			echo "missing zig; install Homebrew or install Zig manually" >&2; exit 1; \
		fi; \
	fi
	@if ! command -v cargo-zigbuild >/dev/null 2>&1; then \
		cargo install cargo-zigbuild; \
	fi
else
	@if ! command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1 && ! command -v cargo-zigbuild >/dev/null 2>&1; then \
		if command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then \
			sudo apt-get update; \
			sudo apt-get install -y gcc-arm-linux-gnueabihf; \
		else \
			echo "missing arm-linux-gnueabihf-gcc; install it or install zig + cargo-zigbuild" >&2; exit 1; \
		fi; \
	fi
endif

setup-appload-rm2:
	./scripts/setup-rm2-appload.sh "$(RM2_SSH)"

test:
	cargo test

build-rm2-qtfb:
ifeq ($(UNAME_S),Darwin)
	cargo zigbuild --release --target $(TARGET) --features rm2
else ifeq ($(HAS_ARM_GCC),yes)
	./build-rm2-qtfb.sh
else ifeq ($(HAS_ZIGBUILD),yes)
	cargo zigbuild --release --target $(TARGET) --features rm2
else
	@echo "No rM2 cross linker found. Run: make setup-rm2" >&2
	@exit 1
endif

bundle-rm2-qtfb: build-rm2-qtfb
	./scripts/make-rm2-qtfb-bundle.sh

install-rm2-qtfb: test bundle-rm2-qtfb
	ssh "$(RM2_SSH)" "test -d '$(RM2_APPLOAD_DIR)' || { echo 'missing $(RM2_APPLOAD_DIR); install xovi/AppLoad first' >&2; exit 1; }"
	ssh "$(RM2_SSH)" "mkdir -p '$(RM2_APPLOAD_DIR)/riddle-rm2'"
	scp -O -r "dist/riddle-rm2/." "$(RM2_SSH):$(RM2_APPLOAD_DIR)/riddle-rm2/"
	@echo "Installed The Diary. Open AppLoad on the tablet, tap Reload, then launch The Diary."

smoke-rm2-hardware: bundle-rm2-qtfb
	./scripts/smoke-rm2-hardware.sh "$(RM2_SSH)"

clean:
	cargo clean
