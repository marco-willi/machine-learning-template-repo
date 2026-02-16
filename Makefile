#################################################################################
# GLOBALS                                                                       #
#################################################################################

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

#################################################################################
# COMMANDS                                                                      #
#################################################################################

.PHONY: help
help: ## Show all available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

##### DATA

.PHONY: data
data: ## Download and prepare data
	@echo "Preparing Data"

##### TRAIN & DEV

.PHONY: tests
tests: ## Run tests
	pytest tests/
