#!/bin/bash -l
#SBATCH --job-name="job_name"
#SBATCH --time=06:00:00
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --partition=performance

# shellcheck source=/dev/null
source ../.env

echo "Doing something"

# Singularity Image
SIF_DIR="${HOST_DATA_PATH}/singularity"
SIF_FILE="${CONTAINER_NAME}_${IMAGE_TAG}.sif"


mkdir -p "${SIF_DIR}"

# Singularity Bindings and Env variables
# shellcheck disable=SC2016
export SINGULARITY_DOCKER_USERNAME='$oauthtoken'
export SINGULARITY_DOCKER_PASSWORD="${CONTAINER_REGISTRY_PULL_TOKEN}"
export SINGULARITY_BIND="${HOST_DATA_PATH}:${DATA_PATH},${HOST_CODE_PATH}:${CODE_PATH}"
export HF_HOME="${HF_HOME}"


# Pull Image
cd "${SIF_DIR}" || exit
singularity pull --name "${SIF_FILE}" docker://"${CONTAINER_REGISTRY}":"${IMAGE_TAG}"

singularity exec --nv "${SIF_DIR}/${SIF_FILE}" python "${CODE_PATH}/scripts/my_script.py"
