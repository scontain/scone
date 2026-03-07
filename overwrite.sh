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

cargo install --git https://github.com/scontain/k8s-scone.git --branch main --root overwrite scone-td-build

cargo install --git https://github.com/scontain/kubectl-plugin --branch main --root overwrite kubectl-scone


# copy local kubectl-provision
# to-do: install from upstream repo
cp /home/ubuntu/.cargo/bin/kubectl-provision overwrite/bin

cargo install --git  https://github.com/scontain-gmbh/kubectl-scone-azure.git --branch laerson/workshop --root overwrite kubectl-scone-azure

