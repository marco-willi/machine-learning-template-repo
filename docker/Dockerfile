FROM jupyter/minimal-notebook:2023-01-16

LABEL maintainer=""
LABEL description=""

USER root

RUN apt-get update && \
    apt-get install -y  \
        make && \
    apt-get clean

USER $NB_UID

COPY environment.yaml /tmp/environment.yaml

RUN mamba env update -n base --file /tmp/environment.yaml && \
    mamba clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"
