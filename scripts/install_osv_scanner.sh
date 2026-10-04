#!/usr/bin/env bash

set -euo pipefail 
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF
# Deploying Confidential SCONE OSV Scanner

Welcome to the Confidential **SCONE OSV SCAN (SOS)** deployment guide. This document explains how to deploy SOS and into a Kubernetes cluster.

SOS consists of a 

- Confidential database that contains 
  - an open source vulnerability database which is periodically updated, and
  - SBOMs of applications
- A scanner service that checks if a SBOM contains vulnerabilities that should or must be fixed

We run the database and the service confidential 

- to ensure the integrity of the database and the query results, and
- to prevent adversaries to easily determine the vulnerabilities of given applications.

---

## Table of Contents

1. [Prerequisites](#prerequisites)   
2. [Deployment Steps](#deployment-steps)  

---

## Prerequisites


To deploy SCONE OSV Scanner, ensure you have the following:

- **kubectl**: Check the [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installation quide

- **Access to a Kubernetes Cluster**:
  Check the [Confidential MariaDB Deployment Guide](./database/CONFIDENTIAL-MARIADB-DEPLOYMENT.md) for details on how to create a cluster. 

- **Access to a MariaDB Server**
  You can use the provided [Native MariaDB deployment guide](./database/NATIVE-MARIADB-DEPLOYMENT.md) or the [Confidential MariaDB Deployment Guide](./database/CONFIDENTIAL-MARIADB-DEPLOYMENT.md) to deploy a MariaDB to a cluster.

- **Access to the SOS images**: 'registry.scontain.com/scone.cloud/sos-images' 

- **Access to the SCONE CLI image**: 'registry.scontain.com/scone.cloud/sconecli'

## Deployment Steps

### 1. SOS Image Versions

Your Kubernetes cluster needs access to container images at 'registry.scontain.com/scone.cloud/sos-images'). The container images are versioned, you can determine the latest version as follows:

EOF
printf "${RESET}"

VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)
echo "The latest stable version of SCONE is $VERSION"
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

### 2. Ensure SOS namespace exists

We create the 'sos' namespace in an idempotent fashion: we create 'sos' if it doesn’t exist, 
and do nothing if it already exists.

Moreover, we ensure that secret 'sconeapps' is injected in the namespace if image secret manager runs in the cluster:

EOF
printf "${RESET}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: sos
  annotations:
    sconeapps/inject-pull-secret: "true"
EOF
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF


### 3. Determine MRENCLAVEs of the programs

Determine the MRENCLAVES of the two SOS images:

EOF
printf "${RESET}"

export DB_MANAGER_IMAGE="registry.scontain.com/scone.cloud/sos-images/dbmanager:${VERSION}"
echo DB_MANAGER_IMAGE=\"$DB_MANAGER_IMAGE\"

DB_MANAGER_MRENCLAVE="$(docker run --rm  --platform linux/amd64 --pull always --entrypoint="" -e SCONE_HASH=1 "$DB_MANAGER_IMAGE" /bin/osvdbmanager | tr -d '\r')"
echo DB_MANAGER_MRENCLAVE=\"$DB_MANAGER_MRENCLAVE\"

export OSV_SCANNER_IMAGE="registry.scontain.com/scone.cloud/sos-images/osvscan:${VERSION}"
echo OSV_SCANNER_IMAGE=\"$OSV_SCANNER_IMAGE\"

OSV_SCANNER_MRENCLAVE="$(docker run --rm  --platform linux/amd64 --pull always --entrypoint="" -e SCONE_HASH=1 "$OSV_SCANNER_IMAGE" /bin/osvscan | tr -d '\r')"
echo OSV_SCANNER_MRENCLAVE=\"$OSV_SCANNER_MRENCLAVE\"
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

### 4. Check that image pull secret exists for SOS Images

The SOS images require a pull secret. Hence, we check that the pull secret 'sconeapps' exists in namespace 'sos':

EOF
printf "${RESET}"

kubectl get secret sconeapps -n sos >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret 'sconapps' does not exist - please create the secret." ; exit 1; }
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

In case the secret 'sconeapps' does not yet exist, please see <https://sconedocs.github.io/2_operator_installation/#automatically-injecting-pull-secrets>
for details on how to inject the image pull secret.

### 5. Prepare the SOS CAS Policy

We provide two template policies for the CAS policy:

- [sos-cas-policy-maxscale-template.yaml](manifests/sos-cas-policy-maxscale-template.yaml)
  Use this template if you deployed the [Confidential MariaDB](./CONFIDENTIAL-MARIADB-DEPLOYMENT.md) and need to import secrets from the maxscale cas session

Choose the template that fits your case, copy its contents to a new file (e.g., 'sos.yaml'), and replace the placeholders with the actual values (check the comments in the templates for details).

Here are the values that you need to add:

- **secrets[mariadb_ca_certificate].value**: CA certificate of the native mariaDB server. If you used the script to generate the certificates you can use the [getca.sh](../scripts/getca.sh) script to get the CA certificate:
  '''bash
  # In the scripts directory
  chmod +x getca.sh
  ./getca.sh mariadb.yaml
  '''
- **secrets[osvscan_certificate].san[ip]**: External IP address of the OSV Scan service. You can get it by running:
  
- '''bash
  kubectl -n sos get services
  '''

### 4. Create CAS Session

Be sure that you are at the [scone](../scone) directory.

EOF
printf "${RESET}"

export CAS="cas"
export CAS_NAMESPACE="default"
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

EOF
printf "${RESET}"

sconecas
scone session create sos.yaml
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

### 4. Deploying OSV Scanner in namespace 'sos'

We can apply the 

kubectl apply -f sos-manifest.yaml

### 5. Verify Deployment

EOF
printf "${RESET}"

watch kubectl get pods -n sos
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

You should see the pods running, and then an error (except for the mariadb pod). That's because the CAS Sessions don't exist yet.

EOF
printf "${RESET}"

