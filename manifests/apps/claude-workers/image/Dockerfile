# Claude worker image: Claude Code + gh + Node/Python toolchains + Kubernetes tooling.
# Build and push to the local registry:
#   docker buildx build --platform linux/amd64 -t registry.laskonet.com/claude-worker:latest --push .
FROM node:24-bookworm-slim

ARG CLAUDE_CODE_VERSION=2.1.283
ARG KUBECTL_VERSION=v1.37.1
ARG HELM_VERSION=v4.3.0
ARG KUSTOMIZE_VERSION=v5.8.1
ARG YQ_VERSION=v4.53.6
ARG TALOSCTL_VERSION=v1.14.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq less openssh-client procps ripgrep unzip \
      python3 python3-pip python3-venv build-essential \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | tar -xz --strip-components=1 -C /usr/local/bin linux-amd64/helm \
 && curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin kustomize \
 && curl -fsSLo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
 && curl -fsSLo /usr/local/bin/talosctl "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-amd64" \
 && chmod +x /usr/local/bin/kubectl /usr/local/bin/yq /usr/local/bin/talosctl

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN corepack enable pnpm \
 && npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && npm cache clean --force

# The node image already has uid/gid 1000 ("node"). HOME is overridden to the workspace PVC at runtime.
USER 1000:1000
WORKDIR /workspace
