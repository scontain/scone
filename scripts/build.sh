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

Environment (required with --push or --push-to; the pushed image is signed with cosign):
  COSIGN_KEY       cosign private key: a file path or a KMS URI (e.g., awskms://...).
                   Keep the key outside this repository.
  COSIGN_PASSWORD  Password of the cosign private key.
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

if [[ -n "${PUSH_OPTION}" ]]; then
  # Check before building: pushing takes long, and an unsigned image is skipped by
  # sconecli.md, which only installs tools from workshop images with a valid signature.
  missing_cosign_settings=()
  [[ -n "${COSIGN_KEY:-}" ]] || missing_cosign_settings+=(COSIGN_KEY)
  [[ -n "${COSIGN_PASSWORD:-}" ]] || missing_cosign_settings+=(COSIGN_PASSWORD)
  if [[ ${#missing_cosign_settings[@]} -gt 0 ]]; then
    echo "Error: --${PUSH_OPTION} signs the pushed image and requires: ${missing_cosign_settings[*]}" >&2
    echo "       Set COSIGN_KEY to the cosign private key (file path or KMS URI) and" >&2
    echo "       COSIGN_PASSWORD to its password. Keep the key outside this repository." >&2
    exit 1
  fi
  require_command cosign
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

BASE_IMAGE="scone:build-base"

# Stage 1: everything that needs neither Docker nor cluster credentials.
docker buildx build --load \
  --build-context overrides="$override_root" \
  -t "$BASE_IMAGE" \
  --build-arg SCONE_VERSION="${SCONE_VERSION}" \
  --file Dockerfile .

# Stage 2: prerequisite_check.sh and install_sconecli.sh drive a Docker daemon, which
# a "docker build" step cannot reach without exposing the daemon on TCP. Run them in a
# container with the host socket mounted instead, and commit that container.
#
# Everything is mounted below a tmpfs on /mnt (empty in the image), so neither the
# credentials nor their mount points end up in the committed image. The socket is not
# mounted at /var/run/docker.sock: check_docker_setup.sh would chgrp/chmod it there,
# changing the host socket. Settings go in the command, not "-e", so that the commit
# does not bake them into the image's environment.
install_container=""
cleanup_install_container() {
  if [[ -n "$install_container" ]]; then
    docker rm -f "$install_container" >/dev/null 2>&1 || true
  fi
}
trap cleanup_install_container EXIT

# shellcheck disable=SC2016 # The container's shell expands these.
install_container="$(docker create \
  --tmpfs /mnt \
  --mount type=bind,src=/var/run/docker.sock,dst=/mnt/docker.sock \
  --mount type=bind,src="$HOME/.kube/config",dst=/mnt/kube/config,readonly \
  --mount type=bind,src="$HOME/.docker/config.json",dst=/mnt/docker/config.json,readonly \
  --entrypoint /bin/bash "$BASE_IMAGE" -c '
    set -euo pipefail
    export DOCKER_HOST=unix:///mnt/docker.sock
    export DOCKER_CONFIG=/mnt/docker
    export KUBECONFIG=/mnt/kube/config
    export SCONE_VERSION="$1" VERSION="$1" CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
    # This build replaces the workshop image: do not install tools from its previous version.
    export SCONE_WORKSHOP_IMAGE=""
    cd /root/scone
    docker version
    ./scripts/prerequisite_check.sh
    ./scripts/install_sconecli.sh
  ' install "$SCONE_VERSION")"
docker start --attach "$install_container"
docker commit \
  --change 'ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]' \
  --change 'CMD ["/bin/bash"]' \
  "$install_container" scone:latest >/dev/null
docker rm "$install_container" >/dev/null
install_container=""
# Untag only; the layers stay referenced by scone:latest.
docker image rm "$BASE_IMAGE" >/dev/null

# Bypass the toolbox entrypoint: this check needs neither a cluster nor credentials.
docker run --rm --network none --entrypoint /bin/bash \
  -e SCONE_VERSION="$SCONE_VERSION" scone:latest \
  -c 'exec /root/scone/scripts/check-scone-tooling.sh'

docker tag scone:latest "registry.scontain.com/workshop/scone:${IMAGE_TAG}"
echo "Built image: registry.scontain.com/workshop/scone:${IMAGE_TAG}"

if [[ -n "${PUSH_IMAGE}" ]]; then
  docker tag scone:latest "${PUSH_IMAGE}:${IMAGE_TAG}"
  docker push "${PUSH_IMAGE}:${IMAGE_TAG}"
  # Sign the pushed digest, not the tag, which could be moved in the meantime.
  pushed_ref="$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' \
    "${PUSH_IMAGE}:${IMAGE_TAG}" | grep -F -m1 "${PUSH_IMAGE}@" || true)"
  if [[ -z "$pushed_ref" ]]; then
    echo "Error: cannot determine the digest of the pushed image ${PUSH_IMAGE}:${IMAGE_TAG}" >&2
    exit 1
  fi
  # cosign reads the key password from COSIGN_PASSWORD.
  cosign sign --yes --key "$COSIGN_KEY" "$pushed_ref"
  echo "Signed image: $pushed_ref"

  # Releasing the current stable version also moves "latest" to it. Images pushed
  # under another tag (e.g., validation images via --image-tag) never move "latest".
  stable_version="$(tr -d '[:space:]' < "$repo_root/stable.txt")"
  if [[ "$IMAGE_TAG" == "$SCONE_VERSION" && "$SCONE_VERSION" == "$stable_version" ]]; then
    docker tag scone:latest "${PUSH_IMAGE}:latest"
    docker push "${PUSH_IMAGE}:latest"
    latest_ref="$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' \
      "${PUSH_IMAGE}:latest" | grep -F -m1 "${PUSH_IMAGE}@" || true)"
    if [[ "$latest_ref" != "$pushed_ref" ]]; then
      echo "Error: ${PUSH_IMAGE}:latest has digest '${latest_ref}'; expected ${pushed_ref}" >&2
      exit 1
    fi
    cosign sign --yes --key "$COSIGN_KEY" "$latest_ref"
    echo "Tagged and signed ${PUSH_IMAGE}:latest -> $latest_ref (stable version $stable_version)"
  else
    echo "Not moving ${PUSH_IMAGE}:latest: tag ${IMAGE_TAG} is not the stable release ${stable_version} (stable.txt)."
  fi
else
  echo "WARNING: Image was not pushed. It is available only to the local Docker daemon."
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
