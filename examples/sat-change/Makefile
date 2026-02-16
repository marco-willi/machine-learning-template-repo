.PHONY: data tests download verify extract prepare train infer vectorize evaluate validate docs \
        smoke-test \
        gcp-setup gcp-setup-remote gcp-sync-env gcp-sync-up gcp-sync-down gcp-sync-data gcp-train \
        lambda-list lambda-setup lambda-ssh lambda-sync-env lambda-setup-remote lambda-setup-gcp lambda-sync-data lambda-train-auto lambda-train-multi lambda-terminate

#################################################################################
# GLOBALS                                                                       #
#################################################################################

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

# Data directories
RAW_DIR := data/raw
EXTRACTED_DIR := data/extracted
PROCESSED_DIR := data/processed

# xBD dataset files and checksums
TRAIN_TAR := $(RAW_DIR)/train_images_labels_targets.tar.tar
TEST_TAR := $(RAW_DIR)/test_images_labels_targets.tar.tar
HOLD_TAR := $(RAW_DIR)/hold_images_labels_targets.tar.tar

TRAIN_SHA1 := b37a4ef4ee9c909e2b19d046e49d42ee3965714b
TEST_SHA1 := 86ed3dba2f8d16ceceb75d451005054fefa9616f
HOLD_SHA1 := fe7f162f0895bfaff134cab3abc23872f38d17da

# GCP Configuration (from .env)
GCP_PROJECT_ID := ${GCP_PROJECT_ID}
GCP_ZONE := ${GCP_ZONE}
GCS_BUCKET := ${GCS_BUCKET}

# GitHub (for remote setup, from .env)
GITHUB_USER := ${GITHUB_USER}
GITHUB_ACCESS_TOKEN := ${GITHUB_ACCESS_TOKEN}


#################################################################################
# COMMANDS                                                                      #
#################################################################################

help:	## Show this help.
	@sed -ne '/@sed/!s/## //p' $(MAKEFILE_LIST)

##### DATA

download: ## Download dataset (manual - requires xView2 registration)
	@echo "=================================================================="
	@echo "xBD/xView2 dataset requires manual download after registration."
	@echo "1. Register at https://xview2.org/"
	@echo "2. Download the following files to $(RAW_DIR)/:"
	@echo "   - Challenge training set (~7.8 GB)"
	@echo "   - Challenge test set (~2.6 GB)"
	@echo "   - Challenge holdout set (~2.6 GB)"
	@echo "3. Run 'make verify' to check file integrity"
	@echo "=================================================================="

verify: ## Verify SHA1 checksums of downloaded tarballs
	@echo "Verifying SHA1 checksums..."
	@echo "Expected checksums:"
	@echo "  train: $(TRAIN_SHA1)"
	@echo "  test:  $(TEST_SHA1)"
	@echo "  hold:  $(HOLD_SHA1)"
	@echo ""
	@if [ -f "$(TRAIN_TAR)" ]; then \
		ACTUAL=$$(sha1sum "$(TRAIN_TAR)" 2>/dev/null | cut -d' ' -f1 || shasum -a 1 "$(TRAIN_TAR)" | cut -d' ' -f1); \
		if [ "$$ACTUAL" = "$(TRAIN_SHA1)" ]; then \
			echo "✓ train: $$ACTUAL"; \
		else \
			echo "✗ train: $$ACTUAL (MISMATCH!)"; \
			exit 1; \
		fi; \
	else \
		echo "✗ train: FILE NOT FOUND"; \
		exit 1; \
	fi
	@if [ -f "$(TEST_TAR)" ]; then \
		ACTUAL=$$(sha1sum "$(TEST_TAR)" 2>/dev/null | cut -d' ' -f1 || shasum -a 1 "$(TEST_TAR)" | cut -d' ' -f1); \
		if [ "$$ACTUAL" = "$(TEST_SHA1)" ]; then \
			echo "✓ test:  $$ACTUAL"; \
		else \
			echo "✗ test:  $$ACTUAL (MISMATCH!)"; \
			exit 1; \
		fi; \
	else \
		echo "✗ test:  FILE NOT FOUND"; \
		exit 1; \
	fi
	@if [ -f "$(HOLD_TAR)" ]; then \
		ACTUAL=$$(sha1sum "$(HOLD_TAR)" 2>/dev/null | cut -d' ' -f1 || shasum -a 1 "$(HOLD_TAR)" | cut -d' ' -f1); \
		if [ "$$ACTUAL" = "$(HOLD_SHA1)" ]; then \
			echo "✓ hold:  $$ACTUAL"; \
		else \
			echo "✗ hold:  $$ACTUAL (MISMATCH!)"; \
			exit 1; \
		fi; \
	else \
		echo "✗ hold:  FILE NOT FOUND"; \
		exit 1; \
	fi
	@echo ""
	@echo "All checksums verified successfully!"

extract: ## Extract tarballs to data/extracted/
	@echo "Extracting datasets to $(EXTRACTED_DIR)/..."
	@mkdir -p $(EXTRACTED_DIR)
	@if [ ! -d "$(EXTRACTED_DIR)/train" ]; then \
		echo "Extracting train set..."; \
		tar -xf "$(TRAIN_TAR)" -C $(EXTRACTED_DIR); \
	else \
		echo "Train set already extracted, skipping."; \
	fi
	@if [ ! -d "$(EXTRACTED_DIR)/test" ]; then \
		echo "Extracting test set..."; \
		tar -xf "$(TEST_TAR)" -C $(EXTRACTED_DIR); \
	else \
		echo "Test set already extracted, skipping."; \
	fi
	@if [ ! -d "$(EXTRACTED_DIR)/hold" ]; then \
		echo "Extracting holdout set..."; \
		tar -xf "$(HOLD_TAR)" -C $(EXTRACTED_DIR); \
	else \
		echo "Holdout set already extracted, skipping."; \
	fi
	@echo "Extraction complete!"
	@echo "Dataset structure:"
	@ls -la $(EXTRACTED_DIR)/

prepare: extract ## Tile images and create manifests
	python scripts/prepare_data.py

data: verify extract prepare ## Verify, extract, and prepare data (full pipeline)

##### TRAIN & INFERENCE

train: ## Train model
	python scripts/train.py

infer: ## Run inference and export rasters
	python scripts/infer.py

vectorize: ## Polygonize results to GeoPackage
	python scripts/vectorize.py

evaluate: ## Evaluate model (usage: make evaluate RUN_ID=<run_id> [SPLIT=val|test], default: test)
	@if [ -z "$(RUN_ID)" ]; then \
		echo "ERROR: RUN_ID not specified"; \
		echo "Usage: make evaluate RUN_ID=<run_id> [SPLIT=val|test]"; \
		echo "Example: make evaluate RUN_ID=unet_20251229_135939 SPLIT=test"; \
		exit 1; \
	fi
	@SPLIT=$${SPLIT:-test}; \
	python scripts/evaluate.py $(RUN_ID) --split $$SPLIT

validate: ## Evaluate model on validation set (shortcut for: make evaluate SPLIT=val)
	$(MAKE) evaluate RUN_ID=$(RUN_ID) SPLIT=val


##### TESTING & QUALITY

smoke-test: ## Run quick local test (small subset, 2 epochs)
	python scripts/train.py experiment=smoke_test

##### GCP

# Ensure gcloud is in PATH for all GCP targets
GCLOUD_PATH := /opt/google-cloud-sdk/bin
export PATH := $(GCLOUD_PATH):$(PATH)

gcp-setup: ## Create GCP VM for training (europe-west4-b)
	@GCP_PROJECT_ID=$(GCP_PROJECT_ID) GCS_BUCKET=$(GCS_BUCKET) \
		./scripts/gcp/setup_vm.sh

gcp-sync-up: ## Upload extracted and processed data to GCS
	@echo "Uploading data to gs://$(GCS_BUCKET)/data/..."
	@gcloud auth application-default print-access-token > /dev/null 2>&1 || \
		(echo "ERROR: Not authenticated. Run 'gcloud auth application-default login'" && exit 1)
	@if [ -d "$(EXTRACTED_DIR)" ]; then \
		echo "Syncing extracted data..."; \
		gsutil -m rsync -r $(EXTRACTED_DIR) gs://$(GCS_BUCKET)/data/extracted/; \
	fi
	@if [ -d "$(PROCESSED_DIR)" ]; then \
		echo "Syncing processed data..."; \
		gsutil -m rsync -r $(PROCESSED_DIR) gs://$(GCS_BUCKET)/data/processed/; \
	fi
	@echo "Upload complete!"

gcp-sync-down: ## Download logs from GCS
	@echo "Downloading logs from gs://$(GCS_BUCKET)/logs/..."
	@gcloud auth application-default print-access-token > /dev/null 2>&1 || \
		(echo "ERROR: Not authenticated. Run 'gcloud auth application-default login'" && exit 1)
	mkdir -p logs
	gsutil -m rsync -r gs://$(GCS_BUCKET)/logs/ logs/
	@echo "Download complete!"

gcp-sync-data: ## Download extracted and processed data from GCS (run on remote VM)
	@echo "Downloading data from gs://$(GCS_BUCKET)/data/..."
	@gcloud auth application-default print-access-token > /dev/null 2>&1 || \
		(echo "ERROR: Not authenticated. Run 'gcloud auth application-default login'" && exit 1)
	mkdir -p data/extracted data/processed
	gsutil -m rsync -r gs://$(GCS_BUCKET)/data/extracted/ data/extracted/ || true
	gsutil -m rsync -r gs://$(GCS_BUCKET)/data/processed/ data/processed/ || true
	@echo "Download complete!"

##### LAMBDA LABS

# Lambda Labs Configuration (from .env)
LAMBDA_API_KEY := ${LAMBDA_API_KEY}
LAMBDA_INSTANCE_TYPE := ${LAMBDA_INSTANCE_TYPE}
LAMBDA_REGION := ${LAMBDA_REGION}
LAMBDA_SSH_KEY_NAME := ${LAMBDA_SSH_KEY_NAME}
LAMBDA_INSTANCE_IP := ${LAMBDA_INSTANCE_IP}

lambda-list: ## List Lambda Labs instances and available types
	@./scripts/lambda/list_instances.sh

lambda-setup: ## Launch a new Lambda Labs instance
	@./scripts/lambda/setup_instance.sh

lambda-ssh: ## SSH into Lambda Labs instance
	@if [ -z "$(LAMBDA_INSTANCE_IP)" ]; then \
		if [ -f /tmp/lambda_instance_ip ]; then \
			ssh ubuntu@$$(cat /tmp/lambda_instance_ip); \
		else \
			echo "ERROR: LAMBDA_INSTANCE_IP not set. Run 'make lambda-list' to find IP."; \
			exit 1; \
		fi \
	else \
		ssh ubuntu@$(LAMBDA_INSTANCE_IP); \
	fi

lambda-sync-env: ## Upload .env file to Lambda instance
	@if [ -z "$(LAMBDA_INSTANCE_IP)" ] && [ -f /tmp/lambda_instance_ip ]; then \
		scp .env ubuntu@$$(cat /tmp/lambda_instance_ip):~/.env; \
	elif [ -n "$(LAMBDA_INSTANCE_IP)" ]; then \
		scp .env ubuntu@$(LAMBDA_INSTANCE_IP):~/.env; \
	else \
		echo "ERROR: LAMBDA_INSTANCE_IP not set"; \
		exit 1; \
	fi
	@echo ".env uploaded"

lambda-setup-remote: ## Setup environment on Lambda instance (uploads .env, clones repo, installs deps)
	@echo "Uploading .env and setup script..."
	@IP=$${LAMBDA_INSTANCE_IP:-$$(cat /tmp/lambda_instance_ip 2>/dev/null)}; \
	if [ -z "$$IP" ]; then echo "ERROR: No instance IP found"; exit 1; fi; \
	scp .env ubuntu@$$IP:~/.env; \
	scp scripts/lambda/setup_remote.sh ubuntu@$$IP:~/setup_remote.sh; \
	echo "Running remote setup..."; \
	ssh ubuntu@$$IP "GITHUB_USER=$(GITHUB_USER) GITHUB_ACCESS_TOKEN=$(GITHUB_ACCESS_TOKEN) GCS_BUCKET=$(GCS_BUCKET) bash ~/setup_remote.sh"

lambda-sync-data: ## Download data from GCS on Lambda instance (run on remote)
	@echo "Downloading data from gs://$(GCS_BUCKET)/data/..."
	mkdir -p data/extracted data/processed
	gsutil -m rsync -r gs://$(GCS_BUCKET)/data/extracted/ data/extracted/ || true
	gsutil -m rsync -r gs://$(GCS_BUCKET)/data/processed/ data/processed/ || true
	@echo "Download complete!"

lambda-setup-gcp: ## Authenticate with GCP and set project (run on Lambda instance)
	@GCP_PROJECT_ID=$(GCP_PROJECT_ID) GCS_BUCKET=$(GCS_BUCKET) ./scripts/lambda/setup_gcp.sh

lambda-train-auto: ## Train with auto-sync to GCS and terminate on success (run on Lambda in tmux!)
	@./scripts/lambda/train_and_shutdown.sh $(ARGS)

lambda-train-multi: ## Train multiple experiments sequentially, then terminate (run on Lambda in tmux!)
	@./scripts/lambda/train_multi.sh $(ARGS)

lambda-terminate: ## Terminate Lambda Labs instance
	@./scripts/lambda/terminate_instance.sh
