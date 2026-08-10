# Nanobot

基于容器的 AI 开发环境镜像：预装 Node.js LTS、pnpm、uv、Python 3.13 与 [nanobot-ai](https://pypi.org/project/nanobot-ai/) 工具，通过 Docker Compose 一键启动，开箱即用。

## 特性

- **开箱即用**：`docker compose run --rm nanobot` 直接启动 nanobot
- **双生态工具链**：pnpm（Node.js）与 uv（Python）并存，依赖缓存通过命名卷持久化
- **中文友好**：预装 Noto CJK 字体，容器内 locale 为 `en_US.UTF-8`
- **多架构**：CI 发布 `linux/amd64` 与 `linux/arm64` 镜像

## 快速开始

```bash
# 构建镜像（本地构建需先设置 DOCKERHUB_USERNAME，如：export DOCKERHUB_USERNAME=myname）
docker compose build

# 启动 nanobot
docker compose run --rm nanobot

# 进入交互式 shell
docker compose run --rm nanobot bash

# 在容器内执行任意命令
docker compose run --rm nanobot <command>
```

## 持久化

| 挂载 | 容器路径 | 说明 |
| --- | --- | --- |
| `./workspace` | `/workspace` | 工作目录，项目文件持久化到宿主机 |
| `pnpm-store`（命名卷） | `/root/.local/share/pnpm/store` | pnpm 依赖缓存 |
| `uv-cache`（命名卷） | `/root/.cache/uv` | uv/Python 依赖缓存 |

## 镜像内容

基础镜像 `node:lts-trixie-slim`（Debian Trixie），按层安装：

1. Noto CJK 中文字体与 git、build-essential 等开发工具
2. pnpm（官方安装脚本）
3. uv（官方安装脚本）
4. Python 3.13（经 uv 安装并软链为系统默认 `python3`）
5. `nanobot-ai`（`uv tool install`）

## 发布流程

GitHub Actions（`.github/workflows/build.yml`）自动构建多架构镜像并推送到 Docker Hub：

- push 到 `main` → 发布 `latest`
- 推送严格 semver tag（如 `v1.2.3`）→ 发布 `1.2.3` / `1.2` / `1`
- Pull Request（涉及构建相关文件）→ 仅构建验证，不推送
- 需要在仓库中配置 `DOCKERHUB_USERNAME` 与 `DOCKERHUB_TOKEN` secrets

## 项目结构

| 文件 | 说明 |
| --- | --- |
| `Dockerfile` | 镜像定义，编号分层的安装步骤 |
| `docker-compose.yml` | 运行配置：挂载、环境变量、缓存卷 |
| `entrypoint.sh` | 容器入口：补全 PATH 后执行用户命令 |
| `.github/workflows/build.yml` | CI 构建与发布流水线 |
