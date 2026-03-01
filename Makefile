# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
COLS              ?= 100
ROWS              ?= 50
FONT_SIZE         ?= 22

DOC_SCRIPTS := \
	docs/install_sconecli.sh \
	docs/reconcile_scone_operator.sh \
	docs/install_cas.sh \
	docs/prerequisite_check.sh \
	docs/install_prometheus_grafana.sh \
	docs/run_golang.sh \
	docs/k8s_cli.sh

CASTS := $(DOC_SCRIPTS:.sh=.cast)
GIFS  := $(DOC_SCRIPTS:.sh=.gif)

DEPS := asciinema agg

RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RESET := \033[0m

.PHONY: all record gif check-deps clean help
all: record gif

# -----------------------------
# Record
# -----------------------------
docs/%.cast: docs/%.sh | check-deps
	@echo "$(YELLOW)Recording to $@…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "SCONE demo: $*" -c "$<" "$@"
	@echo "$(GREEN)✓ Recorded: $@$(RESET)"


# -----------------------------
# Render GIF
# -----------------------------
docs/%.gif: docs/%.cast | check-deps
	@echo "$(YELLOW)Exporting GIF to $@…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" --font-size "$(FONT_SIZE)" "$<" "$@"
	@echo "$(GREEN)✓ GIF created: $@$(RESET)"

# Front-door targets, matching your original names
record: $(CASTS)
gif:   $(GIFS)

# -----------------------------
# Dependency checks
# -----------------------------
check-deps:
	@missing=""
	@for cmd in $(DEPS); do command -v $$cmd >/dev/null 2>&1 || missing="$$missing $$cmd"; done; \
	if [ -n "$$missing" ]; then \
	  echo "$(RED)Missing tools:$$missing$(RESET)\n"; \
	  echo "Install:"; \
	  echo "  asciinema : (Linux) your pkg mgr | (macOS) brew install asciinema | (PyPI 2.x) pipx install asciinema"; \
	  echo "  agg: https://github.com/asciinema/agg"; \
	  exit 1; \
	else \
	  echo "$(GREEN)All dependencies available: $(DEPS)$(RESET)"; \
	fi

# -----------------------------
# Utilities
# -----------------------------
clean:
	@rm -f $(CASTS) $(GIFS)
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | gif | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD COLS ROWS FONT_SIZE"
