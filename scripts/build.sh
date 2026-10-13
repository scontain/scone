#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/build.sh --version <SCONE_VERSION> [--push | --push-to <IMAGE_NAME>] [--image-tag <TAG>] [--test] [--verbose] [--help]

Build the SCONE workshop image as described in README.md.
Run SCONE_VERSION=<SCONE_VERSION> ./overwrite.sh first to prepare its binaries.

Options:
  --version <SCONE_VERSION>  Required SCONE release to build (also the default image tag).
  --push                     Push to registry.scontain.com/workshop/scone:<SCONE_VERSION>.
  --push-to <IMAGE_NAME>     Push to <IMAGE_NAME>:<SCONE_VERSION> (must not include a tag).
  --image-tag <TAG>          Override the image tag without changing the SCONE release.
  --test                     Deploy toolbox and run demos; requires --push or --push-to.
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
PUSH_OPTION=""
IMAGE_TAG=""
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
    --image-tag)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "Error: --image-tag requires a value" >&2
        exit 1
      fi
      IMAGE_TAG="$2"
      shift 2
      ;;
    --test)
      RUN_TEST=true
      shift
      ;;
    --push)
      if [[ -n "${PUSH_OPTION}" ]]; then
        echo "Error: use either --push or --push-to, not both" >&2
        exit 1
      fi
      PUSH_OPTION="push"
      PUSH_IMAGE="registry.scontain.com/workshop/scone"
      shift
      ;;
    --push-to)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        echo "Error: --push-to requires a value" >&2
        usage
        exit 1
      fi
      if [[ -n "${PUSH_OPTION}" ]]; then
        echo "Error: use either --push or --push-to, not both" >&2
        exit 1
      fi
      PUSH_OPTION="push-to"
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

if [[ "$RUN_TEST" == true && -z "$PUSH_OPTION" ]]; then
  echo "Error: --test requires --push or --push-to" >&2
  exit 1
fi

IMAGE_TAG="${IMAGE_TAG:-$SCONE_VERSION}"
if [[ ! "$IMAGE_TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]]; then
  echo "Error: invalid image tag: $IMAGE_TAG" >&2
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
override_root="${SCONE_OVERRIDE_DIR:-$repo_root/overwrite}"
if [[ ! -d "$override_root" ]]; then
  echo "Error: missing override directory: $override_root" >&2
  exit 1
fi
override_root="$(cd "$override_root" && pwd)"
override_bin="$override_root/bin"
cd "$repo_root"

# Validate the files Docker will copy, not unrelated executables on the host PATH.
SCONE_VERSION="$SCONE_VERSION" ./scripts/check-scone-tooling.sh --overrides-dir "$override_bin"
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
  --build-context overrides="$override_root" \
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

docker --context dind tag scone:latest "registry.scontain.com/workshop/scone:${IMAGE_TAG}"
echo "Built image: registry.scontain.com/workshop/scone:${IMAGE_TAG}"

if [[ -n "${PUSH_IMAGE}" ]]; then
  docker --context dind tag scone:latest "${PUSH_IMAGE}:${IMAGE_TAG}"
  docker --context dind push "${PUSH_IMAGE}:${IMAGE_TAG}"
else
  echo "WARNING: Image was not pushed. It is available only to the dind Docker daemon."
  echo "         To make it available to Kubernetes, rerun with --push."
fi

if [[ "${RUN_TEST}" == true ]]; then
  require_command kubectl
  require_command git

  export CLI_IMAGE="${PUSH_IMAGE}:${IMAGE_TAG}"

  # Complete deployment before testing, so an existing Ready pod cannot be tested.
  export CLI_NAMESPACE="${CLI_NAMESPACE:-scone-tools}"
  K8S_CLI_DEPLOY_ONLY=true SCONE_VERSION="$SCONE_VERSION" ./scripts/k8s_cli.sh
  deployed_image="$(kubectl -n "$CLI_NAMESPACE" get deployment scone-toolbox \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="scone-toolbox")].image}')"
  if [[ "$deployed_image" != "$CLI_IMAGE" ]]; then
    echo "Error: toolbox uses $deployed_image; expected $CLI_IMAGE" >&2
    exit 1
  fi

  # shellcheck disable=SC2016 # The remote shell expands its own PATH.
  kubectl exec -n "${CLI_NAMESPACE}" deploy/scone-toolbox -c scone-toolbox -- \
    env SCONE_VERSION="$SCONE_VERSION" bash -lc '
    set -euo pipefail
    export PATH=/root/.cargo/bin:$PATH
    /root/scone/scripts/check-scone-tooling.sh
    cd /root
    if [[ -d scone-td-build-demos/.git ]]; then
      git -C scone-td-build-demos pull --ff-only
    else
      git clone https://github.com/scontain-gmbh/scone-td-build-demos
    fi
    cd scone-td-build-demos
    unset CONFIRM_ALL_ENVIRONMENT_VARIABLES
    ./scripts/run-all-scripts.sh
  '
fi
