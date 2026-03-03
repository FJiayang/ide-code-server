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
ENV GOPATH=/home/coder/go
ENV PATH=/usr/local/go/bin:/home/coder/go/bin:$PATH

RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz | tar -C /usr/local -xzf - \
    && go version

# Install Go tools
RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
    && go install golang.org/x/tools/cmd/goimports@latest

# Layer 4: Python 3.13 + uv + conda with China mirrors
ENV UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# Install Python 3.13
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.13 \
    python3.13-venv \
    python3.13-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.13 /usr/bin/python3 \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/root/.local/bin:/home/coder/.local/bin:$PATH

# Install Miniconda
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then CONDA_ARCH="x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then CONDA_ARCH="aarch64"; \
    else CONDA_ARCH="$ARCH"; fi && \
    curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-${CONDA_ARCH}.sh -o /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh
ENV PATH=/opt/conda/bin:$PATH

# Layer 5: Node.js (latest LTS) with China mirror
ENV NODE_VERSION=22

# Install Node.js from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Configure npm mirror and install pnpm, yarn
RUN npm config set registry https://registry.npmmirror.com --global \
    && npm install -g pnpm yarn \
    && pnpm config set registry https://registry.npmmirror.com \
    && yarn config set registry https://registry.npmmirror.com

# Layer 6: JDK 21 (Temurin) + Maven 3.9.x with Aliyun mirror
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk
ENV MAVEN_VERSION=3.9.9
ENV PATH=$JAVA_HOME/bin:$PATH

# Install JDK 21 (Eclipse Temurin)
RUN apt-get update && apt-get install -y --no-install-recommends \
    temurin-21-jdk \
    && rm -rf /var/lib/apt/lists/*

# Install Maven
RUN curl -fsSL https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz | tar -C /opt -xzf - \
    && ln -s /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn

# Layer 7: Ruby (rbenv) + Rails with Ruby China mirror
ENV RBENV_ROOT=/home/coder/.rbenv
ENV PATH=$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH

# Install Ruby dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    build-essential \
    libssl-dev \
    libyaml-dev \
    libreadline6-dev \
    zlib1g-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm6 \
    libgdbm-dev \
    && rm -rf /var/lib/apt/lists/*

# Install rbenv and ruby-build (as root, will be chown'd later)
RUN git clone https://github.com/rbenv/rbenv.git /home/coder/.rbenv \
    && git clone https://github.com/rbenv/ruby-build.git /home/coder/.rbenv/plugins/ruby-build

# Install latest stable Ruby and Rails
RUN /home/coder/.rbenv/plugins/ruby-build/install.sh \
    && RBENV_ROOT=/home/coder/.rbenv /home/coder/.rbenv/bin/rbenv install 3.4.1 \
    && RBENV_ROOT=/home/coder/.rbenv /home/coder/.rbenv/bin/rbenv global 3.4.1 \
    && RBENV_ROOT=/home/coder/.rbenv /home/coder/.rbenv/shims/gem install bundler rails --no-document

# Configure gem mirror
RUN echo "---\n:sources:\n  - https://gems.ruby-china.com/" > /home/coder/.gemrc
