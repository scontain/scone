#!/usr/bin/env bash

# This script installs the latest binaries 
# to be included in the workshop container image.
# The Dockerfile takes them and replaces the
# the binaries that might already exist on the base
# image.

set -e -x

# public repos

cargo install tplenv --root overwrite
cargo install retry-spinner --root overwrite

# install binaries from private repos

export CARGO_NET_GIT_FETCH_WITH_CLI=true

# Pin scone-td-build: later main renames cas-endpoint to cas-address, which the
# current scone-td-build-demos do not use yet. Override with SCONE_TD_BUILD_REV.
cargo install --git https://github.com/scontain/scone-td-build.git --rev "${SCONE_TD_BUILD_REV:-b607bdc}" --root overwrite scone-td-build

cargo install --git https://github.com/scontain/kubectl-plugin --branch main --root overwrite kubectl-scone


# copy local kubectl-provision
# to-do: install from upstream repo
cp /home/ubuntu/.cargo/bin/kubectl-provision overwrite/bin

cargo install --git  https://github.com/scontain-gmbh/kubectl-scone-azure.git --branch laerson/workshop --root overwrite kubectl-scone-azure

