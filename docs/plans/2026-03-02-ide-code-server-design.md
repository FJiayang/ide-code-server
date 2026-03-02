# IDE Code Server - Design Document

**Date**: 2026-03-02
**Status**: Approved

## Overview

Build a comprehensive development environment Docker image based on `codercom/code-server:latest`, integrating multiple programming language runtimes with China mainland mirror acceleration.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Docker Image: ide-code-server                              │
│  Base: codercom/code-server:latest (debian-based)           │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: System Tools (git, yq, kubectl)                   │
│  Layer 2: User Permissions (sudo config)                    │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Go (latest) + gopls + tools                       │
│  Layer 4: Python 3.13 + uv + conda                          │
│  Layer 5: Node.js (latest) + npm/pnpm/yarn                  │
│  Layer 6: JDK 21 (Temurin) + Maven 3.9.x                    │
│  Layer 7: Ruby (rbenv) + Rails                              │
├─────────────────────────────────────────────────────────────┤
│  Layer 8: Directory Structure Setup                         │
│    - /home/coder/project (project files)                    │
│    - /home/coder/.local/share/code-server (extensions)      │
├─────────────────────────────────────────────────────────────┤
│  Layer 9: China Mainland Mirror Configuration               │
│    - Go: GOPROXY=https://goproxy.cn                        │
│    - Python: uv/conda 清华镜像                              │
│    - Node: npmmirror                                        │
│    - Maven: 阿里云镜像                                      │
│    - Ruby/gem: Ruby China                                   │
└─────────────────────────────────────────────────────────────┘
```

## Language Stack

| Language | Version | Tools Included | Mirror |
|----------|---------|----------------|--------|
| Go | latest | gopls, delve, golangci-lint, goimports | goproxy.cn |
| Python | 3.13 | uv, miniconda | pypi.tuna.tsinghua.edu.cn |
| Node.js | latest (LTS) | npm, pnpm, yarn | npmmirror |
| JDK | 21 (Temurin) | Maven 3.9.x | 阿里云 |
| Ruby | latest (rbenv) | Rails, Bundler | Ruby China |

## System Tools

- **git**: Version control
- **yq**: YAML processor
- **kubectl**: Kubernetes CLI

## User Permissions

User `coder` with sudo privileges:

```sudoers
# Allow all commands except su
coder ALL=(ALL) NOPASSWD: ALL, !/usr/bin/su, !/bin/su
```

**Note**: This blocks direct `su` commands but determined users may find workarounds. This provides reasonable deterrence rather than absolute prevention.

## Directory Structure

```
/home/coder/
├── project/                              # Workspace (mount point)
├── .local/share/code-server/extensions/  # VS Code extensions
├── .m2/settings.xml                      # Maven config
├── .npmrc                                # npm config
├── .condarc                              # conda config
├── .gemrc                                # gem config
├── .config/pip/pip.conf                  # pip config
└── ...                                   # Other configs
```

## Mirror Configuration Details

### Go
- Environment: `GOPROXY=https://goproxy.cn,direct`

### Python
- uv: `UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple`
- conda: 清华镜像 in `~/.condarc`
- pip: 清华镜像 in `~/.config/pip/pip.conf`

### Node.js
- npm/pnpm/yarn: `registry=https://registry.npmmirror.com` in `~/.npmrc`

### Maven
- 阿里云镜像 in `~/.m2/settings.xml`

### Ruby
- Ruby China mirror in `~/.gemrc`

## Volume Mount Strategy

**Recommended**: Mount entire `/home/coder` directory for simplicity.

```yaml
services:
  ide-code-server:
    image: ghcr.io/${REPO}/ide-code-server:latest
    volumes:
      - ./data/home:/home/coder
    ports:
      - "8080:8080"
    environment:
      - PASSWORD=yourpassword
```

**Alternative**: Separate mounts for granular control:
```yaml
volumes:
  - ./data/home:/home/coder
  - ./data/project:/home/coder/project
  - ./data/extensions:/home/coder/.local/share/code-server
```

## CI/CD Pipeline

### Build Configuration

- **Platforms**: `linux/amd64`, `linux/arm64`
- **Registry**: GitHub Container Registry (ghcr.io)
- **Image Name**: Matches repository name

### Tags

- `latest` (main branch only)
- `sha-xxxxxx` (short commit hash)
- `YYYYMMDD` (date-based)

### Workflow Features

- QEMU for multi-architecture builds
- Docker Buildx for cross-platform compilation
- GitHub Actions cache for faster rebuilds

## Deliverables

| Item | Description |
|------|-------------|
| `Dockerfile` | Multi-layer single-stage build |
| `.github/workflows/build-and-push.yml` | Multi-arch CI/CD pipeline |
| `README.md` | Usage documentation with docker-compose example |

## Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Build approach | Single-stage layered | Simplicity, good caching |
| Python env | uv primary + conda | Modern tooling + data science support |
| Node package managers | npm + pnpm + yarn | Flexibility for different projects |
| JDK distribution | Eclipse Temurin | Open source, no license issues |
| Ruby management | rbenv + ruby-build | Lightweight, standard approach |
| Volume mount | Whole /home/coder | Simplicity, captures all configs |
| Workspace | /home/coder/project | User preference |