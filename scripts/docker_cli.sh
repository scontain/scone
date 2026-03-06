#!/usr/bin/env bash

set -euo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=${CONFIRM_ALL_ENVIRONMENT_VARIABLES:-"--force"}

CONTAINER_NAME="scone-toolbox"
CLI_IMAGE="registry.scontain.com/workshop/scone"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# SSH not needed for local Docker (we use docker exec instead)
export SSH_PUB_KEY="${SSH_PUB_KEY:-none}"

# Collect registry credentials
export REGISTRY_USER="${REGISTRY_USER:-${SCONE_REGISTRY_USERNAME:-}}"
export REGISTRY_TOKEN="${REGISTRY_TOKEN:-${SCONE_REGISTRY_ACCESS_TOKEN:-}}"

eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )

# Log into the registry
echo "${REGISTRY_TOKEN}" | docker login registry.scontain.com --username "${REGISTRY_USER}" --password-stdin

# Pull the latest image
docker pull "${CLI_IMAGE}"

# Remove existing container if present
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Create the scone-registry-env file for the entrypoint
SCONE_REG_ENV="$(mktemp)"
trap 'rm -f "${SCONE_REG_ENV}"' EXIT
cat > "${SCONE_REG_ENV}" <<SEOF
export REGISTRY_TOKEN="${REGISTRY_TOKEN}"
export REGISTRY_USER="${REGISTRY_USER}"
SEOF

# Validate kubeconfig exists
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Error: kubeconfig not found at ${KUBECONFIG}"
  echo "Set KUBECONFIG to the path of your kubeconfig file."
  exit 1
fi

# Run the container interactively
docker run -it --rm \
  --name "${CONTAINER_NAME}" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${KUBECONFIG}":/kubeconfig:ro \
  -v "${SCONE_REG_ENV}":/scone-registry/scone-registry-env:ro \
  -v scone-toolbox-rustup:/root/.rustup \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  "${CLI_IMAGE}"
