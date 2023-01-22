.PHONY: docker-build docker-run docker-push

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
	cd ./docker/${IMAGE_TAG}; docker build . -t ${CONTAINER_REGISTRY}:${IMAGE_TAG}

docker-run:	## Run docker container
	docker run \
		-v ${HOST_PROJECT_ROOT}:${CONTAINER_PROJECT_ROOT} \
		-it -d 
		--user ${CURRENT_UID}:${CURRENT_GID} \
		--shm-size 12G \
		--name template_repo ${CONTAINER_REGISTRY}:${IMAGE_TAG}

docker-push: ## Push image to registry
	docker login -u ${GIT_USER_NAME} -p ${CONTAINER_REGISTRY_PUSH_TOKEN} ${CONTAINER_REGISTRY}
	docker push ${CONTAINER_REGISTRY}:${IMAGE_TAG}
