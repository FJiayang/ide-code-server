# IDE Code Server

A comprehensive development environment Docker image based on code-server, pre-configured with multiple programming language runtimes and China mainland mirror acceleration.

## Features

- **Base**: codercom/code-server:latest
- **User**: `coder` with passwordless sudo (su blocked)
- **Languages**: Go, Python 3.13, Node.js, JDK 21, Ruby/Rails
- **Tools**: git, curl, wget, vim, dnsutils (nslookup), yq, kubectl, gopls, uv, conda, pnpm, yarn, Maven

## Quick Start

```bash
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/project:/home/coder/project \
  -e PASSWORD=yourpassword \
  ghcr.io/your-username/ide-code-server:latest
```

Access at http://localhost:8080

## Volume Mounts

### Recommended External Mounts

For better persistence and performance, mount these directories externally:

| Container Path | Purpose | Description |
|----------------|---------|-------------|
| `/home/coder/project` | Workspace | Main workspace directory |
| `/home/coder/.local/share/code-server` | VS Code Data | Extensions, settings, and user data |
| `/home/coder/.npm` | npm Cache | npm global cache |
| `/home/coder/.local/share/pnpm` | pnpm Store | pnpm package store |
| `/home/coder/go` | Go Packages | GOPATH for user-installed Go packages |
| `/home/coder/.cache/uv` | uv Cache | uv Python package cache |
| `/home/coder/.cache/pip` | pip Cache | pip package cache |
| `/home/coder/.m2/repository` | Maven Repo | Maven local repository |

### Minimal Setup

```bash
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/project:/home/coder/project \
  -v $(pwd)/code-server:/home/coder/.local/share/code-server \
  -e PASSWORD=yourpassword \
  ghcr.io/your-username/ide-code-server:latest
```

### Full Setup with All Mounts

```bash
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/project:/home/coder/project \
  -v $(pwd)/code-server:/home/coder/.local/share/code-server \
  -v $(pwd)/npm:/home/coder/.npm \
  -v $(pwd)/pnpm:/home/coder/.local/share/pnpm \
  -v $(pwd)/go:/home/coder/go \
  -v $(pwd)/cache/uv:/home/coder/.cache/uv \
  -v $(pwd)/cache/pip:/home/coder/.cache/pip \
  -v $(pwd)/m2:/home/coder/.m2/repository \
  -e PASSWORD=yourpassword \
  ghcr.io/your-username/ide-code-server:latest
```

## Docker Compose

### Minimal Configuration

```yaml
services:
  ide-code-server:
    image: ghcr.io/your-username/ide-code-server:latest
    volumes:
      - ./project:/home/coder/project
      - ./code-server:/home/coder/.local/share/code-server
    ports:
      - "8080:8080"
    environment:
      - PASSWORD=yourpassword
    restart: unless-stopped
```

### Full Configuration with All Mounts

```yaml
services:
  ide-code-server:
    image: ghcr.io/your-username/ide-code-server:latest
    volumes:
      # Workspace
      - ./project:/home/coder/project
      # VS Code extensions and settings
      - ./code-server:/home/coder/.local/share/code-server
      # Node.js package caches
      - ./npm:/home/coder/.npm
      - ./pnpm:/home/coder/.local/share/pnpm
      # Go packages (GOPATH)
      - ./go:/home/coder/go
      # Python package caches
      - ./cache/uv:/home/coder/.cache/uv
      - ./cache/pip:/home/coder/.cache/pip
      # Maven local repository
      - ./m2:/home/coder/.m2/repository
    ports:
      - "8080:8080"
    environment:
      - PASSWORD=yourpassword
    restart: unless-stopped
```

## Benefits of External Mounts

1. **VS Code Extensions** (`/home/coder/.local/share/code-server`)
   - Extensions persist across container rebuilds
   - Share extensions between containers
   - Faster startup after rebuild

2. **Package Caches** (`/home/coder/.npm`, `/home/coder/.local/share/pnpm`, etc.)
   - Avoid re-downloading packages
   - Share caches between containers
   - Faster dependency installation

3. **Language Packages** (`/home/coder/go`, `/home/coder/.m2/repository`)
   - Persist globally installed packages
   - Go tools installed via `go install`
   - Maven dependencies cached locally

## Installed Languages

| Language | Version | Tools | Mirror |
|----------|---------|-------|--------|
| Go | 1.24.0 | gopls, delve, golangci-lint | goproxy.cn |
| Python | 3.13 | uv, conda | pypi.tuna.tsinghua.edu.cn |
| Node.js | 22 LTS | npm, pnpm, yarn | npmmirror |
| JDK | 21 | Maven 3.9.11 | Aliyun |
| Ruby | 3.4.1 | Rails, Bundler | Ruby China |

## Build

```bash
docker build -t ide-code-server .
```

## License

MIT
