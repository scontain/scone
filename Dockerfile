FROM registry.scontain.com/cicd/sconecli:6.1.0-rc.0 AS sconectl

FROM registry.scontain.com/cicd/container-diff AS builder

FROM ubuntu:24.04
ARG DOCKER_HOST
ARG KUBECTL_VERSION="v1.33.2"
ARG YQ_VERSION="v4.46.1"
ARG SCONE_VERSION="7.0.0-alpha.1"
ENV DEBIAN_FRONTEND=noninteractive 

COPY --from=sconectl \
    /usr/local/bin/apply \
    /usr/local/bin/gen-policy  \
    /usr/local/bin/mesh \
    /usr/local/bin/scone_genservice \
    /usr/local/bin/scone_verify \
    /usr/local/bin/sconify_image \
    /usr/local/bin/verify \
    /usr/local/bin/genservice \
    /usr/local/bin/scone_apply \
    /usr/local/bin/scone_mesh \
    /usr/local/bin/sign-policy \
    /usr/local/bin/


COPY --from=builder /usr/bin/container-diff-linux-amd64   /usr/local/bin/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    gpg \
    jq \
    gnupg-agent \
    git \
    apt-transport-https \
    software-properties-common \
    ca-certificates \
    gettext \
    wget \
    unzip \
    build-essential \
    pkg-config \
    libssl-dev \
    gcc-multilib \
    xz-utils \
    vim \
    less \
    dnsutils \
    bash-completion && \
    apt-get install -y --no-install-recommends openssh-server && \
    apt-get update && \
    apt-get -y install sudo && \
    \
    # Install GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    \
    # install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws && \
    # Install Docker
    curl -fsSL https://get.docker.com | sh && \
    \
    # Install cosign
    curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" && \
    mv cosign-linux-amd64 /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign && \
    \
    # Install kubectl with verification
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256 && \
    echo "$(cat kubectl.sha256) kubectl" | sha256sum --check && \
    chmod +x kubectl && \
    mv ./kubectl /usr/local/bin/ && \
    rm kubectl.sha256 && \
    \
    # Install yq
    curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" | \
    tar xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/yq_linux_amd64 && \
    ln -sf /usr/local/bin/yq_linux_amd64 /usr/local/bin/yq && \
    \
    # Install k9s
    wget "https://github.com/derailed/k9s/releases/download/v0.50.4/k9s_linux_amd64.deb" && \
    apt install ./k9s_linux_amd64.deb && \
    rm k9s_linux_amd64.deb && \
    \
    # Clean up in same layer to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /tmp/rs.sh \
    && sh /tmp/rs.sh -y --no-modify-path --profile default \
    && export PATH=$HOME/.cargo/bin:$PATH \
    && rustup default stable \
    && rm /tmp/rs.sh \
    && cargo install sconectl \
    && curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/scontain/SH/refs/heads/master/latest/kubectl-provision > $HOME/.cargo/bin/kubectl-provision \
    && chmod +x $HOME/.cargo/bin/kubectl-provision \
    && curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh && \
    printf '%s\n' \
      'PasswordAuthentication no' \
      'KbdInteractiveAuthentication no' \
      'ChallengeResponseAuthentication no' \
      'PubkeyAuthentication yes' \
      'PermitRootLogin prohibit-password' \
      > /etc/ssh/sshd_config.d/99-scone.conf

COPY . /root/scone
# Run prerequisite check during build to fail fast if something is missing
# Use a secret mount to provide kubeconfig during build time
# The secret can be provided using: --secret id=kubeconfig,src=$HOME/.kube/config

RUN export PATH=$HOME/.cargo/bin:$PATH && cargo install tplenv && cargo install retry-spinner

ENV RUSTUP_PERMIT_COPY_RENAME=1

RUN --mount=type=secret,id=kubeconfig,target=/root/.kube/config,required=true \
    --mount=type=secret,id=dockerconfig,target=/root/.docker/config.json,required=true \
    docker version && \
    cd /root/scone \
    && export PATH=$HOME/.cargo/bin:$PATH \
    && CONFIRM_ALL_ENVIRONMENT_VARIABLES="" VERSION=${SCONE_VERSION} ./scripts/prerequisite_check.sh \
    && CONFIRM_ALL_ENVIRONMENT_VARIABLES="" VERSION=${SCONE_VERSION} ./scripts/install_sconecli.sh

ENV DOCKER_CONFIG=/root/.docker

# check if newer local k8s-scone is available and use it
RUN --mount=type=bind,source=overwrite,target=/overwrite \
    [ -f /overwrite/bin/k8s-scone ] && cp /overwrite/bin/k8s-scone /usr/bin/k8s-scone || true

RUN --mount=type=bind,source=overwrite,target=/overwrite \
    [ -f /overwrite/bin/scone-td-build ] && cp /overwrite/bin/scone-td-build $HOME/.cargo/bin/scone-td-build || true

RUN --mount=type=bind,source=overwrite,target=/overwrite \
    [ -f /overwrite/bin/kubectl-provision ] && cp /overwrite/bin/kubectl-provision $HOME/.cargo/bin/kubectl-provision || true

RUN --mount=type=bind,source=overwrite,target=/overwrite \
    [ -f /overwrite/bin/kubectl-scone ] && cp /overwrite/bin/kubectl-scone $HOME/.cargo/bin/kubectl-scone || true

RUN --mount=type=bind,source=overwrite,target=/overwrite \
    [ -f /overwrite/bin/kubectl-scone-azure ] && cp /overwrite/bin/kubectl-scone-azure $HOME/.cargo/bin/kubectl-scone-azure || true

    RUN apt-get update \
 && apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg \
 && mkdir -p /etc/apt/keyrings \
 && curl -sLS https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
 && chmod go+r /etc/apt/keyrings/microsoft.gpg

RUN AZ_REPO=$(lsb_release -cs) \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" \
    > /etc/apt/sources.list.d/azure-cli.list

RUN apt-get update && apt-get install -y azure-cli

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
WORKDIR /root
CMD ["/bin/bash"]
