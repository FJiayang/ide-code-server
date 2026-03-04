# IDE Code Server - 项目上下文

## 项目概述

这是一个基于 `codercom/code-server` 构建的综合性开发环境 Docker 镜像项目，预配置了多种编程语言运行时和中国大陆镜像加速。目标是为开发者提供一个开箱即用的云端 IDE 环境。

### 核心特性

- **基础镜像**: `codercom/code-server:latest`
- **用户权限**: `coder` 用户，支持无密码 sudo（已禁用 su 命令）
- **多语言支持**: Go、Python 3.13、Node.js 22 LTS、JDK 21、Ruby 3.4.1
- **开发工具**: git、curl、wget、vim、dnsutils (nslookup)、yq、kubectl、gopls、delve、golangci-lint、uv、conda、pnpm、yarn、Maven、Rails
- **镜像加速**: 所有语言包管理器均配置中国大陆镜像源

## 项目结构

```
ide-code-server/
├── Dockerfile                              # 主构建文件（多层单阶段构建）
├── README.md                               # 使用文档
├── .dockerignore                           # Docker 构建排除文件
├── .github/
│   └── workflows/
│       └── build-and-push.yml              # CI/CD 多架构构建流程
└── docs/
    └── plans/                              # 设计与规划文档
        ├── 2026-03-02-ide-code-server-design.md
        └── 2026-03-02-ide-code-server.md
```

## 构建与部署

### 本地构建

```bash
# 构建镜像
docker build -t ide-code-server .

# 本地运行
docker run -d \
  --name ide-code-server \
  -p 8080:8080 \
  -v $(pwd)/data:/home/coder \
  -e PASSWORD=yourpassword \
  ide-code-server:latest
```

### CI/CD 流程

项目使用 GitHub Actions 实现自动化构建和发布：

- **触发条件**: 推送到 `master` 分支 或手动触发
- **构建平台**: `linux/amd64`, `linux/arm64`（并行构建）
- **镜像仓库**: GitHub Container Registry (`ghcr.io`)
- **标签策略**:
  - `latest` - 最新版本（仅 master 分支）
  - `sha-xxxxxx` - 短提交哈希
  - `YYYYMMDD` - 日期标签

### 多架构构建策略

使用 matrix 策略实现并行多平台构建：
1. 各平台独立构建并推送 digest
2. 合并阶段创建多架构 manifest
3. 最终镜像支持 `linux/amd64` 和 `linux/arm64`

## Dockerfile 分层结构

Dockerfile 采用精心设计的分层结构以优化缓存效率：

| 层 | 内容 | 缓存优化考虑 |
|---|------|-------------|
| Layer 1 | 系统工具 (git, curl, wget, vim, dnsutils, yq, kubectl) | 变更频率最低 |
| Layer 2 | 用户权限配置 (sudo) | 基础配置 |
| Layer 3 | Go 1.24.0 + gopls + delve + golangci-lint | 独立语言环境 |
| Layer 4 | Python 3.13 + uv + Miniforge (conda) | 独立语言环境 |
| Layer 5 | Node.js 22 LTS + npm/pnpm/yarn | 独立语言环境 |
| Layer 6 | JDK 21 (Temurin) + Maven 3.9.11 | 独立语言环境 |
| Layer 7 | Ruby 3.4.1 (rbenv) + Rails | 独立语言环境 |
| Layer 8 | 目录结构 + 镜像配置文件 | 变更频率最高 |

## 镜像源配置

所有包管理器均已配置中国大陆镜像加速：

| 语言/工具 | 镜像源 | 配置位置 |
|----------|--------|----------|
| Go | goproxy.cn | 环境变量 `GOPROXY` |
| Python (pip/uv) | pypi.tuna.tsinghua.edu.cn | `~/.config/pip/pip.conf`, 环境变量 `UV_INDEX_URL` |
| conda | conda-forge (默认) | Miniforge 默认配置 |
| Node.js (npm/pnpm/yarn) | npmmirror | `~/.npmrc` |
| Maven | 阿里云 | `~/.m2/settings.xml` |
| Ruby (gem) | Ruby China | `~/.gemrc` |

## 容器内目录结构

```
/home/coder/
├── project/                              # 工作区（主要挂载点）
├── .local/share/code-server/             # VS Code 扩展目录
├── .m2/settings.xml                      # Maven 配置
├── .npmrc                                # npm 配置
├── .gemrc                                # gem 配置
├── .config/pip/pip.conf                  # pip 配置
├── go/                                   # Go GOPATH
└── .rbenv/                               # Ruby 版本管理
```

## 开发约定

### Dockerfile 编写规范

1. **分层原则**: 按变更频率从低到高排列层，优化构建缓存
2. **清理缓存**: 每个 `apt-get` 或 `curl` 安装后清理缓存文件
3. **架构支持**: 使用 `$(dpkg --print-architecture)` 动态检测架构
4. **用户切换**: 在 Dockerfile 末尾切换回 `coder` 用户

### Git 提交规范

使用 Conventional Commits 格式：

- `feat:` 新功能
- `fix:` Bug 修复
- `docs:` 文档更新
- `chore:` 杂项（构建配置等）

### CI/CD 注意事项

- 镜像名称必须小写（GHCR 要求）
- 使用 `visudo -c` 验证 sudoers 配置语法
- 多架构构建需要矩阵策略和 manifest 合并

### Git 工作流

项目使用以下 Git 工作流程：

#### 分支策略

- `master` - 主分支，受保护，通过 PR 合并
- 功能开发：直接在 `master` 分支提交或创建 feature 分支

#### 日常开发流程

```bash
# 1. 拉取最新代码
git pull origin master

# 2. 查看当前状态
git status

# 3. 添加修改的文件
git add <files>
# 或添加所有更改
git add -A

# 4. 提交（使用 Conventional Commits 格式）
git commit -m "feat: 添加 vim 和 dnsutils 工具"
git commit -m "fix: 修复 ruby 命令找不到的问题"
git commit -m "docs: 更新文档"

# 5. 推送到远程
git push origin master
```

#### 提交类型规范

| 类型 | 说明 | 示例 |
|-----|------|------|
| `feat` | 新功能 | `feat: 添加 vim 编辑器支持` |
| `fix` | Bug 修复 | `fix: 修复容器内 ruby 命令无法识别` |
| `docs` | 文档更新 | `docs: 更新 README 工具列表` |
| `chore` | 构建/工具变更 | `chore: 升级 Go 版本到 1.24` |
| `refactor` | 代码重构 | `refactor: 优化 Dockerfile 分层结构` |
| `test` | 测试相关 | `test: 添加构建验证测试` |

#### CI/CD 自动触发

- 推送到 `master` 分支自动触发构建
- 构建成功后自动推送到 `ghcr.io`
- 生成 `latest`、`sha-xxxxxx`、`YYYYMMDD` 三种标签

## 快速参考命令

```bash
# 查看镜像构建历史
docker history ide-code-server:latest

# 进入容器调试
docker run -it --rm ide-code-server:latest bash

# 查看多架构镜像信息
docker buildx imagetools inspect ghcr.io/fjiayang/ide-code-server:latest

# 本地构建特定平台
docker buildx build --platform linux/amd64 -t ide-code-server:amd64 .

# 手动触发 CI 构建
gh workflow run build-and-push.yml
```

## 相关链接

- [code-server 官方文档](https://coder.com/docs/code-server/latest)
- [Eclipse Temurin JDK](https://adoptium.net/)
- [Miniforge (conda-forge)](https://github.com/conda-forge/miniforge)
- [uv Python 包管理器](https://docs.astral.sh/uv/)
