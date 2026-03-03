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