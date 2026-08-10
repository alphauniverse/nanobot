# AGENTS.md

This file provides guidance to Lingma (lingma.aliyun.com) when working with code in this repository.

## 项目定位

本仓库不是应用源码，而是一个 **Docker 镜像打包项目**：构建一个预装 AI 开发环境的镜像（Node.js LTS + pnpm + uv + Python 3.13 + `nanobot-ai` 工具），通过 Docker Compose 一键运行 `nanobot`。仓库中只有三个核心文件：`Dockerfile`、`docker-compose.yml`、`entrypoint.sh`，外加 GitHub Actions 发布流水线。

## 常用命令

```bash
# 构建镜像（镜像名由 DOCKERHUB_USERNAME 环境变量决定，本地构建需先 export）
docker compose build

# 运行 nanobot（默认 CMD）
docker compose run --rm nanobot

# 进入交互式 shell
docker compose run --rm nanobot bash

# 在容器内执行任意命令
docker compose run --rm nanobot <command>
```

没有测试/lint 步骤；验证改动的标准方式是 `docker compose build` 后 `docker compose run --rm nanobot --version`（或 `bash` 进入容器检查工具链版本）。

## 架构要点

### 镜像分层（Dockerfile）

基础镜像 `node:lts-trixie-slim`（Debian Trixie），按顺序分层安装：

1. apt 包：Noto CJK 中文字体 + git/build-essential 等开发工具，并生成 `en_US.UTF-8` locale
2. pnpm（官方脚本，`PNPM_HOME=/root/.local/share/pnpm`）
3. uv（官方脚本，`UV_HOME=/root/.local/bin`）
4. Python 3.13（`uv python install`，软链到 `/usr/local/bin/python3` 作为系统默认 Python）
5. `nanobot-ai`（`uv tool install`，提供 `nanobot` 命令）；`NANOBOT_VERSION` build arg 非空时钉住该版本（同步工作流传入），留空装 PyPI 最新版——注意 ARG 声明位置在安装命令之前，不要移到其他层

**修改安装步骤时注意层级依赖**：pnpm/uv 的 PATH 依赖各自的 `*_HOME` 环境变量；Python 依赖 uv；nanobot 依赖 uv 管理的 Python。调整顺序会破坏后续层。

### entrypoint.sh 的三种调用模式

入口脚本负责补全 PATH（pnpm、uv 工具目录）和 `UV_PYTHON_PREFERENCE=only-managed`，然后 `exec "$@"`，支持：默认运行 `nanobot`、`bash` 交互 shell、任意自定义命令。交互式终端（`[ -t 0 ]`）会打印环境版本横幅——修改横幅时注意 `echo` 中的对齐空格。

### Compose 持久化设计

- `./workspace:/workspace` 绑定挂载：用户项目文件的持久化（工作目录）
- `pnpm-store`、`uv-cache` 命名卷：跨容器重建缓存依赖
- `image` 字段引用 `${DOCKERHUB_USERNAME:-your-username}/nanobot:${IMAGE_TAG:-latest}`，与 CI 推送的镜像名一致

### CI 发布流程（.github/workflows/）

两条流水线共用 `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` secrets：

**build.yml（仓库自身变更）**：

- 触发：push 到 `main` → `latest`；严格 semver tag（`v1.2.3` 格式）→ `1.2.3`/`1.2`/`1`；PR（仅构建相关文件变更）→ 只构建验证不推送；手动 dispatch
- **paths filter 只放在 `pull_request` 上**：`push` 事件的 `paths` 与 `tags` 是 AND 语义，若同时配置会导致 tag 发布不可靠，修改触发条件时不要把它们合回同一 `push` 块

**sync-upstream.yml（上游版本同步）**：

- 每日定时轮询官方仓库 `HKUDS/nanobot` 的 GitHub Release（与 PyPI `nanobot-ai` 版本一致），通过 Docker Hub tag 存在性检查去重，新版本才构建
- tag 归一化：`v0.1.4.post3` → `0.1.4-post3`（点转连字符），因 post 后缀无法被 metadata-action 的 semver 解析，`is_post` 输出控制 raw tag 启用
- `flavor: latest=true` 使每次上游同步都更新 `latest`；若需重建已发布版本（如 Dockerfile 变更后），用手动 dispatch 的 `force` 输入

公共约定：多架构构建 `linux/amd64,linux/arm64`（QEMU + Buildx），GHA 层缓存；`concurrency` 自动取消同分支/tag 的旧构建

## 修改约定

- `entrypoint.sh` 必须为 LF 行尾与 bash 语法；仓库根目录的 `.gitattributes` 已强制全仓库 LF（`*.sh text eol=lf`），不要删除或放宽它
- Dockerfile 中的分节注释（`# ---` 编号区块）是既有风格，新增安装步骤应沿用并编号
- 若改动 Dockerfile 安装层，记得同步检查 entrypoint.sh 中对应的 PATH/环境变量假设
