set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: devcontainer-check

devcontainer-check:
    .devcontainer/setup.sh check

devcontainer-install:
    .devcontainer/setup.sh install all
