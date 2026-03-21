# IDE Code Server

[English](./README.md) | [简体中文](./README.zh-CN.md)

这是一个基于 code-server 的综合开发环境 Docker 镜像，预装多语言运行时，并针对中国大陆网络环境配置了镜像加速。

## 特性

- **基础镜像**: `codercom/code-server:latest`
- **默认用户**: `coder`（免密 sudo，`su` 被禁用）
- **语言环境**: Go、Python 3.13、Node.js、JDK 21、Ruby/Rails
- **开发工具**: git、curl、wget、vim、tmux、dnsutils (nslookup)、yq、kubectl、gopls、delve、uv、conda、pnpm、yarn、Maven、claude-code

## 快速开始

```bash
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/project:/home/coder/project \
  -e PASSWORD=yourpassword \
  ghcr.io/your-username/ide-code-server:latest
```

访问地址：http://localhost:8080

## 卷挂载

### 推荐挂载目录

为了更好的持久化和性能，建议挂载以下目录：

| 容器路径 | 用途 | 说明 |
|----------------|---------|-------------|
| `/home/coder/project` | 工作区 | 主工作目录 |
| `/home/coder/.local/share/code-server` | VS Code 数据 | 扩展、设置和用户数据 |
| `/home/coder/.npm` | npm 缓存 | npm 全局缓存 |
| `/home/coder/.local/share/pnpm` | pnpm 存储 | pnpm 包存储 |
| `/home/coder/go` | Go 包目录 | 用户安装 Go 包的 GOPATH |
| `/home/coder/.cache/uv` | uv 缓存 | uv Python 包缓存 |
| `/home/coder/.cache/pip` | pip 缓存 | pip 包缓存 |
| `/home/coder/.m2/repository` | Maven 仓库 | Maven 本地仓库 |

### 最小挂载

```bash
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/project:/home/coder/project \
  -v $(pwd)/code-server:/home/coder/.local/share/code-server \
  -e PASSWORD=yourpassword \
  ghcr.io/your-username/ide-code-server:latest
```

### 全量挂载

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

### 最小配置

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

### 全量配置

```yaml
services:
  ide-code-server:
    image: ghcr.io/your-username/ide-code-server:latest
    volumes:
      # 工作区
      - ./project:/home/coder/project
      # VS Code 扩展和设置
      - ./code-server:/home/coder/.local/share/code-server
      # Node.js 包缓存
      - ./npm:/home/coder/.npm
      - ./pnpm:/home/coder/.local/share/pnpm
      # Go 包目录（GOPATH）
      - ./go:/home/coder/go
      # Python 包缓存
      - ./cache/uv:/home/coder/.cache/uv
      - ./cache/pip:/home/coder/.cache/pip
      # Maven 本地仓库
      - ./m2:/home/coder/.m2/repository
    ports:
      - "8080:8080"
    environment:
      - PASSWORD=yourpassword
    restart: unless-stopped
```

## 外部挂载的收益

1. **VS Code 扩展目录** (`/home/coder/.local/share/code-server`)
   - 重建容器后扩展仍然保留
   - 可在多个容器间复用
   - 重建后启动更快

2. **包缓存目录** (`/home/coder/.npm`、`/home/coder/.local/share/pnpm` 等)
   - 避免重复下载依赖
   - 可跨容器复用缓存
   - 提升安装依赖速度

3. **语言包目录** (`/home/coder/go`、`/home/coder/.m2/repository`)
   - 保留全局安装的包
   - 持久化 `go install` 结果
   - Maven 依赖本地复用

## 挂载整个 /home/coder

如果希望最大化持久化，也可以直接挂载整个 `/home/coder`：

```bash
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/coder-home:/home/coder \
  -e PASSWORD=yourpassword \
  ghcr.io/your-username/ide-code-server:latest
```

### 自动初始化

当挂载 `/home/coder`（尤其是空目录）时，容器会自动初始化：

| 文件 | 作用 |
|------|---------|
| `.bashrc` | PATH 恢复、rbenv 初始化，以及旧 rbenv 路径迁移 |
| `.gemrc` | Ruby China 镜像配置 |
| `.m2/settings.xml` | Maven 阿里云镜像配置 |
| `.config/pip/pip.conf` | pip 清华镜像配置 |

同时会自动创建所需目录。  
若历史 shell 配置里引用了 `/home/coder/.rbenv`，启动时会自动迁移到 `/opt/rbenv`。

### 不受挂载影响的系统工具

以下组件安装在系统目录中，即使挂载用户目录也可用：

| 组件 | 安装位置 | 工具 |
|-----------|----------|-------|
| Go Tools | `/opt/go-tools/bin` | gopls, dlv, golangci-lint, goimports |
| Ruby (rbenv) | `/opt/rbenv` | ruby, gem, rails, bundler |
| Python/conda | `/opt/conda` | python, pip, conda |
| JDK | `/opt/temurin-21-jdk` | java, javac, jar |
| Maven | `/opt/apache-maven` | mvn |

## 内置语言

| 语言 | 版本 | 工具 | 镜像 |
|----------|---------|-------|--------|
| Go | 1.26.1 | gopls, delve, golangci-lint | goproxy.cn |
| Python | 3.13 | uv, conda | pypi.tuna.tsinghua.edu.cn |
| Node.js | 22 LTS | npm, pnpm, yarn | npmmirror |
| JDK | 21 | Maven 3.9.11 | Aliyun |
| Ruby | 4.0.2 | Rails, Bundler | Ruby China |

## 构建

```bash
docker build -t ide-code-server .
```

## 许可证

MIT
