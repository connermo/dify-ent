# 本地镜像构建快速指南

基于官方 Dify 代码构建包含 SSO 补丁的本地 Docker 镜像。

## ⚡ 超快速方法（推荐）

### 方法 1: 补丁现有镜像（最快！）
```bash
# 直接对官方镜像应用补丁（几分钟内完成）
./scripts/patch-and-commit.sh

# 或使用 Makefile
cd dify && make patch-official-images
```

### 方法 2: 热修复运行中的容器
```bash
# 对运行中的容器直接应用补丁（秒级完成）
./scripts/hotfix-running-container.sh --commit --restart

# 或使用 Makefile  
cd dify && make hotfix-and-commit
```

## 🚀 完整构建方法

### 方法 3: 一键启动
```bash
# 完整环境搭建（构建镜像 + 启动服务）
./scripts/quick-start.sh

# 使用现有镜像快速启动
./scripts/quick-start.sh --skip-build

# 并行构建（更快）
./scripts/quick-start.sh --parallel
```

## 🔧 手动构建镜像

### 方法 1: 使用构建脚本
```bash
# 构建所有组件
./scripts/build-local-images.sh

# 构建特定组件
./scripts/build-local-images.sh api web

# 查看帮助
./scripts/build-local-images.sh --help
```

### 方法 2: 使用 Makefile
```bash
cd dify

# 应用补丁并构建所有镜像
make build-with-sso-patches

# 分别构建
make build-local-api
make build-local-web
make build-local-worker
```

## 📦 启动服务

```bash
# 1. 启动 Keycloak（SSO 服务）
cd keycloak && docker compose up -d

# 2. 配置环境变量
cp env.local.example .env.local

# 3. 启动 Dify 服务
docker-compose -f docker-compose.local-images.yml up -d
```

## 🌐 访问地址

- **Dify Web**: http://localhost:3000
- **Dify API**: http://localhost:5001  
- **Keycloak 管理**: http://localhost:8280/admin (admin/admin)

## 📋 构建产物

| 镜像名称 | 说明 |
|---------|------|
| `dify-local/dify-api:latest` | API 服务（含 SSO 补丁） |
| `dify-local/dify-web:latest` | Web 前端（含 SSO 补丁） |
| `dify-local/dify-worker:latest` | 后台任务服务 |

## 🔄 开发工作流

### 快速开发循环
```bash
# 1. 启动基础环境（一次性）
cd dify && make dev-quick-start

# 2. 修改代码后快速应用（重复使用）
cd dify && make dev-hotfix

# 3. 或者只对运行中容器热修复
./scripts/hotfix-running-container.sh
```

### 不同场景的选择

| 场景 | 推荐方法 | 时间 | 用途 |
|------|---------|------|------|
| 🆕 首次设置 | `./scripts/patch-and-commit.sh` | ~2-5分钟 | 获取带补丁的镜像 |
| 🔥 开发调试 | `./scripts/hotfix-running-container.sh` | ~10秒 | 快速测试代码修改 |
| 🚀 生产准备 | `./scripts/build-local-images.sh` | ~10-20分钟 | 完整重新构建 |
| ⚡ 快速演示 | `./scripts/quick-start.sh --skip-build` | ~1分钟 | 使用现有镜像启动 |

## 📚 完整文档

详细说明请参考：[LOCAL_BUILD_GUIDE.md](./LOCAL_BUILD_GUIDE.md)

