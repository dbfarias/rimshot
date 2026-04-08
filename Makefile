# rimshot - Developer joke hooks for Claude Code
# https://github.com/dbfarias/rimshot
#
# SPDX-License-Identifier: MIT

.PHONY: install uninstall test lint validate clean help

SHELL := /usr/bin/env bash

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[34m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install rimshot to ~/.claude/rimshot
	@bash install.sh

uninstall: ## Remove rimshot from ~/.claude/rimshot
	@bash uninstall.sh

test: ## Run the test suite
	@bash tests/test_rimshot.sh

lint: ## Run shellcheck on all scripts
	@echo "Running shellcheck..."
	@shellcheck scripts/rimshot.sh install.sh uninstall.sh tests/test_rimshot.sh
	@echo "All scripts passed shellcheck."

validate: ## Validate joke files (UTF-8, no dupes, min count)
	@echo "Validating joke files..."
	@for file in jokes/*.txt; do \
		count=$$(grep -v '^#' "$$file" | grep -v '^$$' | wc -l | tr -d ' '); \
		dupes=$$(grep -v '^#' "$$file" | grep -v '^$$' | sort | uniq -d | wc -l | tr -d ' '); \
		name=$$(basename "$$file"); \
		printf "  %-12s %3d jokes, %d duplicates\n" "$$name" "$$count" "$$dupes"; \
		if [ "$$dupes" -gt 0 ]; then \
			echo "    DUPLICATES:"; \
			grep -v '^#' "$$file" | grep -v '^$$' | sort | uniq -d | sed 's/^/      /'; \
		fi; \
	done
	@echo "Done."

clean: ## Remove temporary files
	@rm -f "${TMPDIR:-/tmp}"/rimshot_cooldown_*
	@echo "Cleaned temporary files."
