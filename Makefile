# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
SCRIPT            ?= docs/install_sconecli.sh
CAS_SCRIPT        ?= docs/install_cas.sh
CAST              ?= docs/demo.cast
CAS_CAST          ?= docs/cas.cast
GIF               ?= docs/demo.gif
CAS_GIF           ?= docs/cas.gif
CAS_TITLE         ?= Installing SCONE CAS
TITLE             ?= Installing SCONE CLI and SCONE Operator
COLS              ?= 100
ROWS              ?= 50
FONT_SIZE         ?= 22

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
$(CAST): $(SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(TITLE)" -c "$(SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CAST)$(RESET)"

$(CAS_CAST): $(CAS_SCRIPT) $(CAST) | check-deps
	@echo "$(YELLOW)Recording to $(CAS_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(CAS_TITLE)" -c "$(CAS_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CAS_CAST)$(RESET)"


# -----------------------------
# Render GIF
# -----------------------------
$(GIF):  $(CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" --font-size "$(FONT_SIZE)" "$(CAST)" "$(GIF)"
	@echo "$(GREEN)✓ GIF created: $(GIF)$(RESET)"

$(CAS_GIF): $(CAS_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(CAS_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" --font-size "$(FONT_SIZE)" "$(CAS_CAST)" "$(CAS_GIF)"
	@echo "$(GREEN)✓ GIF created: $(CAS_GIF)$(RESET)"

# Front-door targets, matching your original names
record: $(CAST) $(CAS_CAST)
gif:   $(GIF) $(CAS_GIF)

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
	@rm -f "$(CAST)" "$(CAS_CAST)" "$(GIF)" "$(CAS_GIF)"
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | gif | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD SCRIPT CAST GIF TITLE FONT_SIZE"
