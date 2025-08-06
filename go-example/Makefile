# Makefile for the Go app

# ---- Config (override on the CLI: e.g., make build BIN=myapp) ----
BIN        ?= java-args-env-file
BUILD_DIR  ?= bin
GO         ?= go
GOFLAGS    ?=
LDFLAGS    ?= -s -w
CGO_ENABLED?= 0

# If GOOS/GOARCH are provided on the CLI, we’ll cross-compile.
# Example: make build GOOS=linux GOARCH=amd64

# Compute executable extension (handles cross-compile if GOOS is set)
TARGET_GOOS := $(if $(GOOS),$(GOOS),$(shell $(GO) env GOOS))
EXEEXT      := $(if $(filter windows,$(TARGET_GOOS)),.exe,)

# Derived paths
OUT := $(BUILD_DIR)/$(BIN)$(EXEEXT)

# Default target
.PHONY: help
help:
	@echo "Usage:"
	@echo "  make build                 # build $(OUT)"
	@echo "  make run ARGS='a b c'      # build and run with args"
	@echo "  make clean                 # remove build artifacts"
	@echo "  make tidy fmt vet test     # housekeeping"
	@echo ""
	@echo "Options (override with VAR=value):"
	@echo "  BIN=$(BIN)"
	@echo "  BUILD_DIR=$(BUILD_DIR)"
	@echo "  GO=$(GO)"
	@echo "  GOFLAGS='$(GOFLAGS)'"
	@echo "  LDFLAGS='$(LDFLAGS)'"
	@echo "  CGO_ENABLED=$(CGO_ENABLED)"
	@echo "  GOOS=$(GOOS) GOARCH=$(GOARCH) CC=$(CC) CXX=$(CXX)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make build GOOS=linux GOARCH=amd64"
	@echo "  make run ARGS='foo bar'"
	@echo "  make clean"

# Ensure build directory exists
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Build the binary (reproducible-ish: -trimpath, no VCS metadata)
.PHONY: build
build: $(BUILD_DIR)
	@echo ">> building $(OUT)"
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build \
		-trimpath -buildvcs=false \
		-ldflags "$(LDFLAGS)" $(GOFLAGS) \
		-o $(OUT) .

# Run (build first), pass args via ARGS="..."
.PHONY: run
run: build
	@echo ">> running $(OUT) $(ARGS)"
	@$(OUT) $(ARGS)

# Housekeeping
.PHONY: tidy fmt vet test
tidy:
	$(GO) mod tidy
fmt:
	$(GO) fmt ./...
vet:
	$(GO) vet ./...
test:
	$(GO) test ./...

# Clean artifacts
.PHONY: clean
clean:
	@echo ">> cleaning $(BUILD_DIR)"
	@rm -rf $(BUILD_DIR)
