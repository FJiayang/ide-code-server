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

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/root/.local/bin:/home/coder/.local/bin:$PATH

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

# Layer 8: Directory structure and config files
RUN mkdir -p /home/coder/project \
    && mkdir -p /home/coder/.local/share/code-server \
    && mkdir -p /home/coder/.m2 \
    && mkdir -p /home/coder/.config/pip

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

# Set ownership for coder user
RUN chown -R coder:coder /home/coder \
    && chown -R coder:coder /opt/conda

USER coder
WORKDIR /home/coder/project
