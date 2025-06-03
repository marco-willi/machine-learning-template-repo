.PHONY: docker-build docker-run docker-push data tests

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

docker-build:	## Build docker image
	docker build . -t ${CONTAINER_REGISTRY}:${IMAGE_TAG}

docker-run:	## Run docker container
	docker run \
		-v ${HOST_CODE_PATH}:${CODE_PATH} \
		-v ${HOST_DATA_PATH}:${DATA_PATH} \
		-it -d \
		-p 8886:8886 \
		--gpus=all \
		--shm-size 12G \
		--name ${CONTAINER_NAME} ${CONTAINER_REGISTRY}:${IMAGE_TAG}

docker-push: ## Push image to registry
	docker login -u ${GIT_USER_NAME} -p ${CONTAINER_REGISTRY_PUSH_TOKEN} ${CONTAINER_REGISTRY}
	docker push ${CONTAINER_REGISTRY}:${IMAGE_TAG}

##### DATA

data: ## Download and prepare data
	echo "Preparing Data"

##### TRAIN & DEV

tests: ## run tests
	pytest tests/