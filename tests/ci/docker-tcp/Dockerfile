# Ubuntu with systemd and Docker, booted as a privileged container so that
# tests/ci/docker-tcp-container.sh can run scripts/enable_docker_tcp.sh and
# scripts/disable_docker_tcp.sh against a real docker.service.
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV container=docker
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       systemd systemd-sysv dbus docker.io curl python3 iproute2 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    # No consoles in a container; these units only fail or wait.
    && systemctl mask getty.target console-getty.service \
    && systemctl enable docker.service docker.socket containerd.service

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
