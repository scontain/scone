#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/build.sh --version <SCONE_VERSION> [--push-to <IMAGE_NAME>] [--test] [--verbose] [--help]

Build the SCONE workshop image as described in README.md.

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

require_command docker
require_command ip
require_command awk

if [[ ! -f "$HOME/.kube/config" ]]; then
  echo "Error: missing kubeconfig file at $HOME/.kube/config" >&2
  exit 1
fi

if [[ ! -f "$HOME/.docker/config.json" ]]; then
  echo "Error: missing docker config file at $HOME/.docker/config.json" >&2
  exit 1
fi

HOSTIP=$(ip route show default | awk '/default/ {print $3}')
HOSTIP="172.17.0.1"

docker context create dind \
  --docker "host=tcp://${HOSTIP}:2375" || true

rm -f registy.credentials.yaml
rm -f Values.credentials.yaml

docker --context dind buildx build \
  --secret id=kubeconfig,src="$HOME/.kube/config" \
  --secret id=dockerconfig,src="$HOME/.docker/config.json" \
  --build-arg DOCKER_HOST="tcp://${HOSTIP}:2375" \
  -t scone:latest \
  --build-arg SCONE_VERSION="${SCONE_VERSION}" \
  --file Dockerfile .

docker tag scone:latest registry.scontain.com/workshop/scone:${SCONE_VERSION}
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
      git clone https://github.com/scontainug/scone-td-build-demos
    fi
    cd scone-td-build-demos
    unset CONFIRM_ALL_ENVIRONMENT_VARIABLES
    ./.run-all-scripts.sh
  '

  cleanup_k8s_cli
  trap - EXIT
fi

if [[ -n "${PUSH_IMAGE}" ]]; then
  docker tag scone:latest "${PUSH_IMAGE}:${SCONE_VERSION}"
  docker push "${PUSH_IMAGE}:${SCONE_VERSION}"
fi
