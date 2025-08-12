# Dify 离线升级和 SSO 补丁应用解决方案

## 🎯 问题描述

在生产环境中，Dify 服务器需要升级并应用 SSO 补丁，但由于以下原因无法直接操作：

1. **无法连接互联网** - 无法拉取新的 Docker 镜像
2. **需要应用 SSO 补丁** - 需要将 Keycloak 集成应用到现有镜像
3. **需要生成新镜像** - 需要创建包含补丁的永久镜像

## 🚀 解决方案概述

我们提供了两种解决方案：

### 方案一：完整离线升级包（推荐）
- 使用 `scripts/offline-upgrade-and-patch.sh` 脚本
- 创建包含完整升级说明的离线包
- 适用于复杂的升级场景

### 方案二：简化离线镜像构建
- 使用 `scripts/build-offline-images.sh` 脚本
- 快速构建包含 SSO 补丁的镜像
- 适用于简单的补丁应用场景

## 📋 前置条件

### 在有网络的环境中准备

1. **下载官方 Dify 镜像**
```bash
docker pull langgenius/dify-api:latest
docker pull langgenius/dify-web:latest
```

2. **验证镜像下载成功**
```bash
docker images | grep langgenius/dify
```

3. **确保有完整的 Dify 代码库**
```bash
git clone https://github.com/langgenius/dify.git
cd dify
```

## 🔧 方案一：完整离线升级包

### 步骤 1：创建离线升级包

在有网络的环境中运行：

```bash
# 克隆 dify-ent 仓库
git clone https://github.com/your-username/dify-ent.git
cd dify-ent

# 运行离线升级脚本
./scripts/offline-upgrade-and-patch.sh
```

### 步骤 2：传输升级包

将生成的 `dify-offline-upgrade-YYYYMMDD` 目录传输到目标服务器：

```bash
# 使用 scp 传输
scp -r dify-offline-upgrade-20241201 user@target-server:/path/to/destination/

# 或使用 rsync
rsync -avz dify-offline-upgrade-20241201/ user@target-server:/path/to/destination/
```

### 步骤 3：在目标服务器上部署

```bash
# 进入升级包目录
cd dify-offline-upgrade-20241201

# 运行快速升级脚本
./quick-upgrade.sh

# 按照说明更新 docker-compose.yaml
# 启动服务
docker compose up -d
```

## 🔧 方案二：简化离线镜像构建

### 步骤 1：构建离线镜像

在有网络的环境中运行：

```bash
# 克隆 dify-ent 仓库
git clone https://github.com/your-username/dify-ent.git
cd dify-ent

# 运行离线镜像构建脚本
./scripts/build-offline-images.sh
```

### 步骤 2：传输镜像文件

将生成的 `dify-sso-images-YYYYMMDD` 目录传输到目标服务器。

### 步骤 3：在目标服务器上部署

```bash
# 进入镜像目录
cd dify-sso-images-20241201

# 运行部署脚本
./deploy.sh

# 使用提供的 docker-compose 文件启动服务
docker compose -f docker-compose.sso.yaml up -d
```

## 📦 升级包内容

### 完整离线升级包包含：

- `dify-api-sso.tar` - 包含 SSO 集成的 API 服务镜像
- `dify-web-sso.tar` - 包含 SSO 集成的 Web 服务镜像
- `UPGRADE_README.md` - 详细的升级说明文档
- `quick-upgrade.sh` - 快速升级脚本

### 简化离线镜像包包含：

- `dify-api-sso.tar` - API 服务镜像
- `dify-web-sso.tar` - Web 服务镜像
- `deploy.sh` - 部署脚本
- `env.example` - 环境变量配置示例
- `docker-compose.sso.yaml` - Docker Compose 配置文件

## 🔧 环境变量配置

### 必需的 SSO 环境变量

```bash
# SSO 认证开关
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Keycloak OAuth 配置
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify

# Dify 服务地址
CONSOLE_API_URL=http://localhost:5001
CONSOLE_WEB_URL=http://localhost:3000

# 用户权限设置
ALLOW_REGISTER=true
ALLOW_CREATE_WORKSPACE=true
```

## 🚀 部署流程

### 1. 准备阶段（有网络环境）

```bash
# 下载官方镜像
docker pull langgenius/dify-api:latest
docker pull langgenius/dify-web:latest

# 创建离线升级包
./scripts/offline-upgrade-and-patch.sh
```

### 2. 传输阶段

```bash
# 传输升级包到目标服务器
scp -r dify-offline-upgrade-20241201/ user@server:/opt/
```

### 3. 部署阶段（目标服务器）

```bash
# 进入升级包目录
cd /opt/dify-offline-upgrade-20241201

# 运行升级脚本
./quick-upgrade.sh

# 更新配置文件
# 启动服务
docker compose up -d
```

## 🔍 故障排除

### 常见问题及解决方案

#### 1. 镜像加载失败

```bash
# 检查镜像文件完整性
ls -la *.tar

# 重新加载镜像
docker load -i dify-api-sso.tar
docker load -i dify-web-sso.tar
```

#### 2. 服务启动失败

```bash
# 检查容器日志
docker compose logs api
docker compose logs web

# 检查环境变量
docker compose exec api env | grep KEYCLOAK
```

#### 3. SSO 功能不工作

```bash
# 验证环境变量
echo $ENABLE_SOCIAL_OAUTH_LOGIN
echo $KEYCLOAK_CLIENT_ID

# 检查 Keycloak 连接
curl -f http://localhost:8280/realms/dify/.well-known/openid-configuration
```

## 📚 最佳实践

### 1. 版本管理

- 为每个升级包添加版本标签
- 保留升级包的备份
- 记录升级时间和内容

### 2. 测试验证

- 在测试环境中先验证升级包
- 验证所有 SSO 功能正常工作
- 检查用户权限设置

### 3. 回滚准备

- 保留原始镜像的备份
- 准备回滚脚本
- 记录回滚步骤

### 4. 监控和日志

- 监控服务启动状态
- 检查错误日志
- 验证用户登录功能

## 🆘 获取帮助

如果遇到问题：

1. 检查本文档的故障排除部分
2. 查看升级包中的详细说明文档
3. 检查 Docker 容器日志
4. 验证环境变量配置
5. 确认 Keycloak 服务状态

## 📅 更新记录

- **2024-12-01**: 创建离线升级解决方案
- **功能**: 支持离线升级 Dify 并应用 SSO 补丁
- **适用场景**: 无法连接互联网的生产环境
