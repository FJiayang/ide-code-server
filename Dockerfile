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
RUN ARCH=$(dpkg --print-architecture) \
    && curl -sL https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_${ARCH} -o /usr/bin/yq \
    && chmod +x /usr/bin/yq

# Install kubectl
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get install -y kubectl \
    && rm -rf /var/lib/apt/lists/*

# Layer 2: User permissions - sudo with su blocked
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
    && echo "coder ALL=(ALL) NOPASSWD: ALL, !/usr/bin/su, !/bin/su" > /etc/sudoers.d/coder-nopasswd \
    && chmod 440 /etc/sudoers.d/coder-nopasswd \
    && visudo -c -f /etc/sudoers.d/coder-nopasswd \
    && rm -rf /var/lib/apt/lists/*

# Layer 3: Go (latest) with China mirror and tools
ENV GO_VERSION=1.24.0
ENV GOPROXY=https://goproxy.cn,direct
ENV PATH=/usr/local/go/bin:/home/coder/go/bin:$PATH

RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz | tar -C /usr/local -xzf - \
    && go version

# Install Go tools
RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
    && go install golang.org/x/tools/cmd/goimports@latest
