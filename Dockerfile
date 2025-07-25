FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ARG KUBECTL_VERSION="v1.28.10"
ARG YQ_VERSION="v4.46.1"

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
    xz-utils && \
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


COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
