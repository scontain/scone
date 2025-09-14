# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
SCRIPT            ?= docs/demo.sh
CAST              ?= docs/demo.cast
CAST_V2           ?= docs/demo.v2.cast
SVG               ?= docs/demo.svg
TITLE             ?= Confidential Caddy demo
COLS              ?= 100

DEPS := asciinema svg-term

RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RESET := \033[0m

.PHONY: all record svg check-deps clean help
all: record svg

# -----------------------------
# Record
# -----------------------------
$(CAST): $(SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(TITLE)" -c "$(SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CAST)$(RESET)"

# -----------------------------
# Ensure v2 for svg-term (auto-detect v1/v2/v3)
# If v3 -> convert to v2; if v1/v2 -> copy through.
# -----------------------------
# Ensure v2 for svg-term (auto-detect reliably; convert v3→v2)
# Not yet enabled since still usig v2
$(CAST_V2): $(CAST) | check-deps
	echo "$(YELLOW)Converting to v2 → $(CAST_V2)…$(RESET)"; \
	asciinema convert -f v2 "$(CAST)" "$(CAST_V2)"; \
	@echo "$(GREEN)✓ Ready: $(CAST_V2)$(RESET)"

# -----------------------------
# Render SVG
# -----------------------------
$(SVG): check-deps
	@echo "$(YELLOW)Exporting SVG to $(SVG)…$(RESET)"
	@cat "$(CAST)" | svg-term --out "$(SVG)" --window --no-cursor  --width $(COLS)
	@echo "$(GREEN)✓ SVG created: $(SVG)$(RESET)"

# Front-door targets, matching your original names
record: $(CAST)
svg:    $(SVG)

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
	  echo "  svg-term  : npm install -g svg-term-cli"; \
	  exit 1; \
	else \
	  echo "$(GREEN)All dependencies available: $(DEPS)$(RESET)"; \
	fi

# -----------------------------
# Utilities
# -----------------------------
clean:
	@rm -f "$(CAST)" "$(CAST_V2)" "$(SVG)"
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | svg | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD SCRIPT CAST CAST_V2 SVG TITLE"
