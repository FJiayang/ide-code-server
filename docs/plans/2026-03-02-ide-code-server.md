# IDE Code Server Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a comprehensive development environment Docker image based on code-server with Go, Python, Node.js, JDK, and Ruby runtimes.

**Architecture:** Single-stage layered Dockerfile with careful layer ordering for optimal caching. GitHub Actions pipeline for multi-architecture (amd64/arm64) builds.

**Tech Stack:** Docker, GitHub Actions, code-server, Go, Python 3.13, Node.js, JDK 21 (Temurin), Maven, Ruby/Rails

---

## Task 1: Create Dockerfile Base and System Tools

**Files:**
- Create: `Dockerfile`

**Step 1: Create Dockerfile with base image and system tools**

```dockerfile
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
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: add Dockerfile base with system tools (git, yq, kubectl)"
```

---

## Task 2: Configure Sudo Permissions

**Files:**
- Modify: `Dockerfile`

**Step 1: Add sudo configuration to Dockerfile**

Append to Dockerfile:

```dockerfile
# Layer 2: User permissions - sudo with su blocked
RUN apt-get update && apt-get install -y sudo \
    && echo "coder ALL=(ALL) NOPASSWD: ALL, !/usr/bin/su, !/bin/su" > /etc/sudoers.d/coder-nopasswd \
    && chmod 440 /etc/sudoers.d/coder-nopasswd \
    && rm -rf /var/lib/apt/lists/*
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: configure sudo for coder user (nopasswd, su blocked)"
```

---

## Task 3: Install Go Environment

**Files:**
- Modify: `Dockerfile`

**Step 1: Add Go installation to Dockerfile**

Append to Dockerfile:

```dockerfile
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
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: install Go ${GO_VERSION} with gopls, delve, golangci-lint"
```

---

## Task 4: Install Python Environment

**Files:**
- Modify: `Dockerfile`

**Step 1: Add Python 3.13 and uv installation**

Append to Dockerfile:

```dockerfile
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
RUN curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh
ENV PATH=/opt/conda/bin:$PATH
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: install Python 3.13 with uv and miniconda"
```

---

## Task 5: Install Node.js Environment

**Files:**
- Modify: `Dockerfile`

**Step 1: Add Node.js installation with npm, pnpm, yarn**

Append to Dockerfile:

```dockerfile
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
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: install Node.js ${NODE_VERSION} with npm, pnpm, yarn (npmmirror)"
```

---

## Task 6: Install JDK and Maven

**Files:**
- Modify: `Dockerfile`

**Step 1: Add JDK 21 (Temurin) and Maven installation**

Append to Dockerfile:

```dockerfile
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
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: install JDK 21 (Temurin) and Maven ${MAVEN_VERSION}"
```

---

## Task 7: Install Ruby and Rails

**Files:**
- Modify: `Dockerfile`

**Step 1: Add Ruby (rbenv) and Rails installation**

Append to Dockerfile:

```dockerfile
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
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: install Ruby 3.4.1 (rbenv) and Rails"
```

---

## Task 8: Configure Mirror Files and Directory Structure

**Files:**
- Modify: `Dockerfile`

**Step 1: Add mirror configuration files and directories**

Append to Dockerfile:

```dockerfile
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

# conda config with Tsinghua mirror
RUN /opt/conda/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/ \
    && /opt/conda/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/ \
    && /opt/conda/bin/conda config --set show_channel_urls yes \
    && cp /root/.condarc /home/coder/.condarc 2>/dev/null || true

# npm config (already configured in Layer 5)
RUN mkdir -p /home/coder/.npm

# Set ownership for coder user
RUN chown -R coder:coder /home/coder \
    && chown -R coder:coder /opt/conda

USER coder
WORKDIR /home/coder/project
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: configure mirror files and directory structure"
```

---

## Task 9: Create GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/build-and-push.yml`

**Step 1: Create the workflow file**

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Get current date for tagging
        run: echo "DATE_TAG=$(date +'%Y%m%d')" >> $GITHUB_ENV

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to the Container registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=latest,enable={{is_default_branch}}
            type=sha,format=short
            type=raw,value=${{ env.DATE_TAG }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Step 2: Commit**

```bash
git add .github/workflows/build-and-push.yml
git commit -m "feat: add GitHub Actions workflow for multi-arch builds"
```

---

## Task 10: Create README Documentation

**Files:**
- Create: `README.md`

**Step 1: Create README with usage instructions**

```markdown
# IDE Code Server

A comprehensive development environment Docker image based on code-server, pre-configured with multiple programming language runtimes and China mainland mirror acceleration.

## Features

- **Base**: codercom/code-server:latest
- **User**: `coder` with passwordless sudo (su blocked)
- **Languages**: Go, Python 3.13, Node.js, JDK 21, Ruby/Rails
- **Tools**: git, yq, kubectl, gopls, uv, conda, pnpm, yarn, Maven

## Quick Start

```bash
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/data:/home/coder \
  -e PASSWORD=yourpassword \
  ghcr.io/your-username/ide-code-server:latest
```

Access at http://localhost:8080

## Volume Mounts

| Container Path | Purpose |
|----------------|---------|
| `/home/coder` | User home directory (configs, caches) |
| `/home/coder/project` | Workspace |
| `/home/coder/.local/share/code-server` | VS Code extensions |

## Docker Compose

```yaml
services:
  ide-code-server:
    image: ghcr.io/your-username/ide-code-server:latest
    volumes:
      - ./data:/home/coder
    ports:
      - "8080:8080"
    environment:
      - PASSWORD=yourpassword
    restart: unless-stopped
```

## Installed Languages

| Language | Version | Tools | Mirror |
|----------|---------|-------|--------|
| Go | 1.24.0 | gopls, delve, golangci-lint | goproxy.cn |
| Python | 3.13 | uv, conda | pypi.tuna.tsinghua.edu.cn |
| Node.js | 22 LTS | npm, pnpm, yarn | npmmirror |
| JDK | 21 | Maven 3.9.9 | Aliyun |
| Ruby | 3.4.1 | Rails, Bundler | Ruby China |

## Build

```bash
docker build -t ide-code-server .
```

## License

MIT
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage instructions"
```

---

## Task 11: Create .dockerignore

**Files:**
- Create: `.dockerignore`

**Step 1: Create .dockerignore**

```
.git
.gitignore
.github
*.md
!README.md
data/
```

**Step 2: Commit**

```bash
git add .dockerignore
git commit -m "chore: add .dockerignore"
```

---

## Task 12: Final Verification and Push

**Step 1: Review all files**

```bash
git status
git log --oneline
```

**Step 2: Verify Dockerfile syntax**

```bash
docker build --check . 2>/dev/null || docker build -f Dockerfile . --target=base 2>&1 | head -20
```

**Step 3: Push to remote**

```bash
git remote add origin https://github.com/username/ide-code-server.git
git push -u origin master
```

**Step 4: Merge to main branch**

```bash
git checkout -b main
git push -u origin main
```

---

## Summary

| Task | Description | Commit Message |
|------|-------------|----------------|
| 1 | Dockerfile base + system tools | feat: add Dockerfile base with system tools |
| 2 | Sudo configuration | feat: configure sudo for coder user |
| 3 | Go installation | feat: install Go with tools |
| 4 | Python installation | feat: install Python 3.13 with uv/conda |
| 5 | Node.js installation | feat: install Node.js with npm/pnpm/yarn |
| 6 | JDK + Maven installation | feat: install JDK 21 and Maven |
| 7 | Ruby + Rails installation | feat: install Ruby and Rails |
| 8 | Mirror configs + directories | feat: configure mirror files and directories |
| 9 | GitHub Actions workflow | feat: add CI/CD workflow |
| 10 | README documentation | docs: add README |
| 11 | .dockerignore | chore: add .dockerignore |
| 12 | Final verification | - |