FROM registry.scontain.com/cicd/sconecli:6.1.0-rc.0 AS sconectl

FROM registry.scontain.com/cicd/container-diff AS builder

FROM ubuntu:24.04
ARG DOCKER_HOST
ARG KUBECTL_VERSION="v1.33.2"
ARG YQ_VERSION="v4.46.1"
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

COPY . /root/scone
# Run prerequisite check during build to fail fast if something is missing
# Use a secret mount to provide kubeconfig during build time
# The secret can be provided using: --secret id=kubeconfig,src=$HOME/.kube/config
ENV DOCKER_CONFIG=/root/.docker

RUN --mount=type=secret,id=kubeconfig,target=/root/.kube/config,required=true \
    --mount=type=secret,id=dockerconfig,target=/root/.docker/config.json,required=true \
    docker version && \
    cd /root/scone \
    && VERSION=6.1.0-rc.0 ./scripts/prerequisite_check.sh

# check if newer local k8s-scone is available and use it
RUN --mount=type=bind,source=overwrite,target=/overwrite \
    [ -f /overwrite/k8s-scone ] && cp /overwrite/k8s-scone /usr/bin/k8s-scone || true

RUN --mount=type=bind,source=overwrite,target=/overwrite \
    [ -f /overwrite/kubectl-provision ] && cp /overwrite/kubectl-provision $HOME/.cargo/bin/kubectl-provision || true

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
WORKDIR /root
CMD ["/bin/bash"]
