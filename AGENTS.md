# AGENTS.md - IDE Code Server

## Purpose
This file helps any incoming agent understand this repository quickly and make safe, consistent changes.

## Project Snapshot
- Project type: Docker image for a cloud IDE based on `codercom/code-server:latest`
- Primary goal: deliver an out-of-the-box development environment with common languages/tools and China-mainland mirrors
- Default runtime user: `coder` (passwordless `sudo`, `su` explicitly blocked)
- Entrypoint: custom `/entrypoint.sh` that runs home initialization before starting `code-server`

## Repository Layout
```text
ide-code-server/
├── Dockerfile
├── README.md
├── AGENTS.md
├── scripts/
│   └── init-home.sh
├── .github/
│   └── workflows/
│       └── build-and-push.yml
└── docs/
    └── plans/
```

## What the Image Installs

### Language runtimes
- Go `1.26.1`
- Python `3.13` (Miniforge/conda)
- Node.js `22` LTS
- JDK `21` (Temurin)
- Maven `3.9.11`
- Ruby `4.0.2` via `rbenv`

### Core tools
- System: `git`, `curl`, `wget`, `vim`, `tmux`, `dnsutils`, `yq`, `kubectl`, `sudo`
- Go tools: `gopls`, `dlv`, `golangci-lint`, `goimports`
- Python tools: `uv`, `conda`
- Node tools: `pnpm`, `yarn`, `@iflow-ai/iflow-cli`, `@anthropic-ai/claude-code`
- Ruby tools: `bundler`, `rails`

## Dockerfile Design (Layered for Cache Efficiency)
| Layer | Main content |
|---|---|
| 1 | Base system tools |
| 2 | User permissions/sudo policy |
| 3 | Go + Go dev tools |
| 4 | Python + uv + conda |
| 5 | Node.js + package managers/CLIs |
| 6 | JDK + Maven |
| 7 | Ruby + rbenv + Rails |
| 8 | Home templates, PATH/bootstrap, entrypoint, mount-friendly defaults |

The layering order is intentional. Keep low-churn dependencies in earlier layers.

## Startup and Mount Behavior (Critical)
- `ENTRYPOINT` runs `/opt/dev-configs/init-home.sh` on every container start.
- This is required because users often bind-mount `/home/coder` or its subdirectories.
- `scripts/init-home.sh` ensures required directories/config files exist.
- It also protects Ruby shell initialization compatibility:
  - Creates `~/.rbenv -> /opt/rbenv` symlink if missing.
  - Migrates legacy `.bashrc` entries from `/home/coder/.rbenv` to `/opt/rbenv`.

If you modify shell bootstrap behavior, update both:
- Docker template generation in `Dockerfile` (`/opt/dev-configs/bashrc-append.sh`)
- Runtime reconciliation logic in `scripts/init-home.sh`

## Mirror/Registry Configuration
| Ecosystem | Mirror/Registry |
|---|---|
| Go | `https://goproxy.cn` |
| pip/uv | `https://pypi.tuna.tsinghua.edu.cn/simple` |
| npm/pnpm/yarn | `https://registry.npmmirror.com` |
| Maven | Aliyun public repository mirror |
| RubyGems | `https://gems.ruby-china.com/` |

## CI/CD Pipeline Summary
Workflow: `.github/workflows/build-and-push.yml`

- Triggers:
  - Push to `master`
  - Manual dispatch
- Build strategy:
  - Matrix build on `linux/amd64` and `linux/arm64`
  - Push per-platform images by digest
  - Merge job creates a multi-arch manifest
- Tags:
  - `latest` (default branch only)
  - short SHA
  - date tag (`YYYYMMDD`)
- Registry:
  - GHCR (`ghcr.io/<owner>/<repo>`, forced lowercase in workflow)
- Post-merge test job validates:
  - default user
  - major tool availability in `bash -i` (simulates VS Code terminal)
  - sudo policy and mirror config

## Agent Change Guide

### If you add/remove a tool
1. Update `Dockerfile`.
2. Update human docs: `README.md`.
3. Update this file (`AGENTS.md`) so future agents stay aligned.
4. Check CI tool-access test section in `.github/workflows/build-and-push.yml` and add/update relevant assertions.

### If you change language versions
1. Update version/env lines in `Dockerfile`.
2. Update version tables in `README.md` and `AGENTS.md`.
3. Watch for path/version-coupled shell settings (example: Ruby gem bin path in `.bashrc` template).

### If you change mount/bootstrap logic
1. Keep `Dockerfile` templates and `scripts/init-home.sh` in sync.
2. Preserve compatibility with existing mounted home directories.
3. Avoid assumptions that `/home/coder` contents are fresh.

## Local Validation Checklist
Use these when Docker is available:
```bash
docker build -t ide-code-server:test .
docker run --rm -it ide-code-server:test bash -i -c "whoami"
docker run --rm -it ide-code-server:test bash -i -c "ruby -v && rails -v && tmux -V"
docker run --rm -it ide-code-server:test bash -i -c "go version && python3 --version && node --version && java -version"
```

## Git and Commit Conventions
- Conventional Commits are preferred:
  - `feat:`
  - `fix:`
  - `docs:`
  - `chore:`
  - `refactor:`
  - `test:`
- Main integration branch is `master`.

## Key Risk Areas
- Shell startup regressions (especially VS Code integrated terminal behavior)
- PATH order changes that hide installed tools
- Volume-mount edge cases under `/home/coder`
- Multi-arch build breaks caused by architecture-specific binary URLs
