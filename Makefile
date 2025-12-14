.PHONY: data tests

#################################################################################
# GLOBALS                                                                       #
#################################################################################

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

#################################################################################
# COMMANDS                                                                      #
#################################################################################


help:	## Show this help.
	@sed -ne '/@sed/!s/## //p' $(MAKEFILE_LIST)

##### DATA

data: ## Download and prepare data
	echo "Preparing Data"

##### TRAIN & DEV

tests: ## run tests
	pytest tests/