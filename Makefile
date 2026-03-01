# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
SCRIPT            ?= docs/install_sconecli.sh
CAS_SCRIPT        ?= docs/install_cas.sh
CAST              ?= docs/demo.cast
CAS_CAST          ?= docs/cas.cast
WEBM              ?= docs/demo.webm
CAS_WEBM          ?= docs/cas.webm
CAS_TITLE         ?= Installing SCONE CAS
TITLE             ?= Installing SCONE CLI and SCONE Operator
COLS              ?= 100

DEPS := asciinema agg

RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RESET := \033[0m

.PHONY: all record webm check-deps clean help
all: record webm

# -----------------------------
# Record
# -----------------------------
$(CAST): $(SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(TITLE)" -c "$(SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CAST)$(RESET)"

$(CAS_CAST): $(CAS_SCRIPT) $(CAST) | check-deps
	@echo "$(YELLOW)Recording to $(CAS_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(CAS_TITLE)" -c "$(CAS_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CAS_CAST)$(RESET)"


# -----------------------------
# Render WEBM
# -----------------------------
$(WEBM):  $(CAST) | check-deps
	@echo "$(YELLOW)Exporting WEBM to $(WEBM)…$(RESET)"
	@agg "$(CAST)" "$(WEBM)"
	@echo "$(GREEN)✓ WEBM created: $(WEBM)$(RESET)"

$(CAS_WEBM): $(CAS_CAST) | check-deps
	@echo "$(YELLOW)Exporting WEBM to $(CAS_WEBM)…$(RESET)"
	@agg "$(CAS_CAST)" "$(CAS_WEBM)"
	@echo "$(GREEN)✓ WEBM created: $(CAS_WEBM)$(RESET)"

# Front-door targets, matching your original names
record: $(CAST) $(CAS_CAST)
webm:   $(WEBM) $(CAS_WEBM)

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
	@rm -f "$(CAST)" "$(CAS_CAST)" "$(WEBM)" "$(CAS_WEBM)"
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | webm | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD SCRIPT CAST WEBM TITLE"
