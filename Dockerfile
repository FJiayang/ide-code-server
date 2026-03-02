# Base image
FROM codercom/code-server:latest

USER root

# Layer 1: System tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install yq
RUN curl -sL https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 -o /usr/bin/yq \
    && chmod +x /usr/bin/yq

# Install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get install -y kubectl \
    && rm -rf /var/lib/apt/lists/*