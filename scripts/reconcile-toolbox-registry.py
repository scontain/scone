#!/usr/bin/env python3
"""Update toolbox registry secrets from the credentials already resolved by tplenv."""

import argparse
import base64
import json
import os
import shlex
import subprocess
import sys


def encoded(value):
    return base64.b64encode(value.encode()).decode("ascii")


def registry_secrets(namespace, registry, username, token):
    """Use the same credential values for image pulls and the toolbox's Docker login."""
    config = json.dumps({"auths": {registry: {
        "username": username,
        "password": token,
        "auth": encoded(f"{username}:{token}"),
    }}})
    environment = "".join(
        f"export {name}={shlex.quote(value)}\n"
        for name, value in (("REGISTRY", registry), ("REGISTRY_USER", username), ("REGISTRY_TOKEN", token))
    )
    items = [
        {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {"name": name, "namespace": namespace},
            "type": "kubernetes.io/dockerconfigjson",
            "data": {".dockerconfigjson": encoded(config)},
        }
        for name in ("scone-registry", "sconeapps")
    ]
    items.append({
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": "scone-registry-env", "namespace": namespace},
        "type": "Opaque",
        "data": {"scone-registry-env": encoded(environment)},
    })
    return {"apiVersion": "v1", "kind": "List", "items": items}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--namespace", required=True)
    args = parser.parse_args()
    names = ("REGISTRY", "REGISTRY_USER", "REGISTRY_TOKEN")
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        print(f"Registry credentials are incomplete: {', '.join(missing)}", file=sys.stderr)
        return 1
    secrets = registry_secrets(args.namespace, *(os.environ[name] for name in names))
    try:
        # Keep credentials out of command arguments and temporary files. Suppress
        # kubectl error payloads, which can contain the submitted secret data.
        result = subprocess.run(
            ["kubectl", "apply", "-f", "-"], input=json.dumps(secrets),
            capture_output=True, text=True, check=False,
        )
    except OSError:
        print("Could not run kubectl to update toolbox registry secrets.", file=sys.stderr)
        return 1
    if result.returncode:
        print(
            f"Could not update registry secrets in namespace {args.namespace} "
            f"(kubectl exit status {result.returncode}). Check cluster access and Secret permissions.",
            file=sys.stderr,
        )
        return 1
    print(f"Updated toolbox registry secrets in namespace {args.namespace}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
