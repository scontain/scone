#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/build.sh --version <SCONE_VERSION> [--push-to <IMAGE_NAME>] [--test] [--verbose] [--help]

Build the SCONE workshop image as described in README.md.
Run SCONE_VERSION=<SCONE_VERSION> ./overwrite.sh first to prepare its binaries.

Options:
  --version <SCONE_VERSION>  Required SCONE version tag to build and tag.
  --push-to <IMAGE_NAME>     Tag and push to <IMAGE_NAME>:<SCONE_VERSION> (must not include a tag).
  --test                     Deploy toolbox via scripts/k8s_cli.sh and run demo scripts.
  --verbose                  Print each command executed by this script.
  --help                     Show this help message.
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

SCONE_VERSION=""
PUSH_IMAGE=""
RUN_TEST=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      if [[ $# -lt 2 ]]; then
        echo "Error: --version requires a value" >&2
        usage
        exit 1
      fi
      SCONE_VERSION="$2"
      shift 2
      ;;
    --test)
      RUN_TEST=true
      shift
      ;;
    --push-to)
      if [[ $# -lt 2 ]]; then
        echo "Error: --push-to requires a value" >&2
        usage
        exit 1
      fi
      PUSH_IMAGE="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

if [[ -z "${SCONE_VERSION}" ]]; then
  echo "Error: --version <SCONE_VERSION> is required" >&2
  usage
  exit 1
fi

if [[ -n "${PUSH_IMAGE}" ]]; then
  if [[ "${PUSH_IMAGE}" == *"@"* ]]; then
    echo "Error: --push-to must not include a digest: ${PUSH_IMAGE}" >&2
    exit 1
  fi
  last_path_component="${PUSH_IMAGE##*/}"
  if [[ "${last_path_component}" == *":"* ]]; then
    echo "Error: --push-to must not include a tag: ${PUSH_IMAGE}" >&2
    exit 1
  fi
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

# Validate the files Docker will copy, not unrelated executables on the host PATH.
SCONE_VERSION="$SCONE_VERSION" ./scripts/check-scone-tooling.sh --overrides-dir "$repo_root/overwrite/bin"
require_command docker

if [[ ! -f "$HOME/.kube/config" ]]; then
  echo "Error: missing kubeconfig file at $HOME/.kube/config" >&2
  exit 1
fi

if [[ ! -f "$HOME/.docker/config.json" ]]; then
  echo "Error: missing docker config file at $HOME/.docker/config.json" >&2
  exit 1
fi

HOSTIP="172.17.0.1"

docker context create dind \
  --docker "host=tcp://${HOSTIP}:2375" || true

docker --context dind buildx build --load \
  --secret id=kubeconfig,src="$HOME/.kube/config" \
  --secret id=dockerconfig,src="$HOME/.docker/config.json" \
  --build-arg DOCKER_HOST="tcp://${HOSTIP}:2375" \
  -t scone:latest \
  --build-arg SCONE_VERSION="${SCONE_VERSION}" \
  --file Dockerfile .

# Bypass the toolbox entrypoint: this check needs neither a cluster nor credentials.
docker --context dind run --rm --network none --entrypoint /bin/bash \
  -e SCONE_VERSION="$SCONE_VERSION" scone:latest \
  -c 'exec /root/scone/scripts/check-scone-tooling.sh'

docker --context dind tag scone:latest "registry.scontain.com/workshop/scone:${SCONE_VERSION}"
echo "Built image: registry.scontain.com/workshop/scone:${SCONE_VERSION}"

if [[ "${RUN_TEST}" == true ]]; then
  require_command kubectl
  require_command git

  if [[ -n "${PUSH_IMAGE}" ]]; then
    export CLI_IMAGE="${PUSH_IMAGE}:${SCONE_VERSION}"
  else
    export CLI_IMAGE="registry.scontain.com/workshop/scone:${SCONE_VERSION}"
  fi

  K8S_CLI_PID=""
  cleanup_k8s_cli() {
    if [[ -n "${K8S_CLI_PID}" ]] && kill -0 "${K8S_CLI_PID}" >/dev/null 2>&1; then
      kill "${K8S_CLI_PID}" >/dev/null 2>&1 || true
      wait "${K8S_CLI_PID}" 2>/dev/null || true
    fi
  }
  trap cleanup_k8s_cli EXIT

  ./scripts/k8s_cli.sh &
  K8S_CLI_PID=$!

  CLI_NAMESPACE="${CLI_NAMESPACE:-scone-tools}"

  kubectl -n "${CLI_NAMESPACE}" wait pod -l app=scone-toolbox --for=condition=Ready --timeout=300s

  kubectl exec -n "${CLI_NAMESPACE}" deploy/scone-toolbox -c scone-toolbox -- bash -lc '
    set -euo pipefail
    cd /root
    if [[ -d scone-td-build-demos/.git ]]; then
      git -C scone-td-build-demos pull --ff-only
    else
      git clone https://github.com/scontain-gmbh/scone-td-build-demos
    fi
    cd scone-td-build-demos
    unset CONFIRM_ALL_ENVIRONMENT_VARIABLES
    ./.run-all-scripts.sh
  '

  cleanup_k8s_cli
  trap - EXIT
fi

if [[ -n "${PUSH_IMAGE}" ]]; then
  docker --context dind tag scone:latest "${PUSH_IMAGE}:${SCONE_VERSION}"
  docker --context dind push "${PUSH_IMAGE}:${SCONE_VERSION}"
fi
