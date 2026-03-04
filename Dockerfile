# Base image
FROM codercom/code-server:latest

USER root

# Layer 1: System tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    vim \
    dnsutils \
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

# Create symlinks for go commands (ensures availability even when PATH is reset)
RUN ln -s /usr/local/go/bin/go /usr/local/bin/go \
    && ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Layer 4: Python + uv + conda with China mirrors
ENV UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# Install Miniforge (conda-forge based, no Anaconda ToS required)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then CONDA_ARCH="x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then CONDA_ARCH="aarch64"; \
    else CONDA_ARCH="$ARCH"; fi && \
    curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${CONDA_ARCH}.sh -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh
ENV PATH=/opt/conda/bin:$PATH

# Install Python 3.13 via conda-forge and create symlinks
RUN conda install -y python=3.13 \
    && conda clean -afy \
    && ln -sf /opt/conda/bin/python /usr/bin/python3 \
    && ln -sf /opt/conda/bin/python /usr/bin/python \
    && ln -sf /opt/conda/bin/pip /usr/bin/pip3 \
    && ln -sf /opt/conda/bin/pip /usr/bin/pip

# Install uv (official recommended way: copy from pre-built image)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Layer 5: Node.js (latest LTS) with China mirror
ENV NODE_VERSION=22

# Install Node.js from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Configure npm mirror and install pnpm, yarn, iflow-cli
RUN npm config set registry https://registry.npmmirror.com --global \
    && npm install -g pnpm yarn @iflow-ai/iflow-cli@latest \
    && pnpm config set registry https://registry.npmmirror.com \
    && yarn config set registry https://registry.npmmirror.com

# Layer 6: JDK 21 (Temurin) + Maven 3.9.x with Aliyun mirror
ENV JAVA_HOME=/opt/temurin-21-jdk
ENV MAVEN_VERSION=3.9.11
ENV PATH=$JAVA_HOME/bin:$PATH

# Install JDK 21 (Eclipse Temurin) - download directly to avoid repo setup
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then JDK_ARCH="x64"; \
    elif [ "$ARCH" = "arm64" ]; then JDK_ARCH="aarch64"; \
    else JDK_ARCH="$ARCH"; fi && \
    curl -fsSL "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_${JDK_ARCH}_linux_hotspot_21.0.6_7.tar.gz" | tar -C /opt -xzf - && \
    mv /opt/jdk-21.0.6+7 /opt/temurin-21-jdk

# Install Maven
RUN curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" | tar -C /opt -xzf - \
    && ln -s /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn

# Create symlinks for java commands (ensures availability even when PATH is reset)
RUN ln -s /opt/temurin-21-jdk/bin/java /usr/local/bin/java \
    && ln -s /opt/temurin-21-jdk/bin/javac /usr/local/bin/javac \
    && ln -s /opt/temurin-21-jdk/bin/jar /usr/local/bin/jar

# Layer 7: Ruby (rbenv) + Rails with Ruby China mirror
# Install rbenv to /opt/rbenv to avoid being overwritten by volume mounts
ENV RBENV_ROOT=/opt/rbenv
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

# Install rbenv and ruby-build to /opt/rbenv (system path, not affected by volume mounts)
RUN git clone https://github.com/rbenv/rbenv.git /opt/rbenv \
    && git clone https://github.com/rbenv/ruby-build.git /opt/rbenv/plugins/ruby-build

# Install latest stable Ruby and Rails
RUN /opt/rbenv/plugins/ruby-build/install.sh \
    && rbenv install 3.4.4 \
    && rbenv global 3.4.4 \
    && rbenv rehash \
    && gem install bundler rails --no-document \
    && rbenv rehash

# Configure gem mirror
RUN echo "---\n:sources:\n  - https://gems.ruby-china.com/" > /home/coder/.gemrc

# Layer 8: Directory structure and config files
# Create system-wide PATH config (not affected by volume mounts on /home/coder)
# This ensures tools are accessible in all shell types (login/non-login, interactive/non-interactive)
RUN echo '#!/bin/sh\n\
# Development tools PATH configuration\n\
# Note: Symlinks in /usr/local/bin provide fallback, this is additional coverage\n\
export PATH=/opt/rbenv/bin:/opt/rbenv/shims:/usr/local/go/bin:/home/coder/go/bin:/opt/temurin-21-jdk/bin:/opt/conda/bin:$PATH' > /etc/profile.d/dev-tools.sh \
    && chmod +x /etc/profile.d/dev-tools.sh

# Create directories for external mounting support
RUN mkdir -p /home/coder/project \
    && mkdir -p /home/coder/.local/share/code-server \
    && mkdir -p /home/coder/.local/share/pnpm \
    && mkdir -p /home/coder/.m2/repository \
    && mkdir -p /home/coder/.config/pip \
    && mkdir -p /home/coder/.npm \
    && mkdir -p /home/coder/.cache/uv \
    && mkdir -p /home/coder/.cache/pip \
    && mkdir -p /home/coder/go

# Declare volumes for external mounting (optional, users can override with -v)
# These can be mounted to persist data across container restarts
VOLUME ["/home/coder/project"]

# Maven settings.xml with Aliyun mirror
RUN echo '<?xml version="1.0" encoding="UTF-8"?>\n\
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"\n\
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n\
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">\n\
  <mirrors>\n\
    <mirror>\n\
      <id>aliyun</id>\n\
      <mirrorOf>central</mirrorOf>\n\
      <name>Aliyun Maven Mirror</name>\n\
      <url>https://maven.aliyun.com/repository/public</url>\n\
    </mirror>\n\
  </mirrors>\n\
</settings>' > /home/coder/.m2/settings.xml

# pip config with Tsinghua mirror
RUN echo '[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple' > /home/coder/.config/pip/pip.conf

# conda config - Miniforge uses conda-forge by default (no Anaconda ToS)
RUN /opt/conda/bin/conda config --set show_channel_urls yes

# npm config (already configured in Layer 5)
RUN mkdir -p /home/coder/.npm

# Add PATH restoration and rbenv initialization to .bashrc
# VS Code terminal is non-login shell, only .bashrc is read
# Use >> to append instead of > to avoid overwriting existing .bashrc
RUN echo '\n\
# Restore Docker ENV PATH (VS Code terminal resets PATH)\n\
export PATH=/opt/rbenv/bin:/opt/rbenv/shims:/opt/temurin-21-jdk/bin:/opt/conda/bin:/usr/local/go/bin:/home/coder/go/bin:$PATH\n\
\n\
# Initialize rbenv\n\
eval "$(/opt/rbenv/bin/rbenv init - bash)"' >> /home/coder/.bashrc

# Set ownership for coder user
# Note: /opt/rbenv is owned by root, but accessible by all users
RUN chown -R coder:coder /home/coder \
    && chown -R coder:coder /opt/conda

USER coder
WORKDIR /home/coder/project
