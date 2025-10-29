# Docker Hub 配置指南

本文档说明如何在 GitHub Actions 中配置 Docker Hub 密钥，以便自动推送镜像到 Docker Hub。

## 🔑 配置 Docker Hub Secrets

### 步骤 1: 获取 Docker Hub Access Token

1. 登录 [Docker Hub](https://hub.docker.com/)
2. 进入 **Account Settings** > **Security** > **New Access Token**
3. 创建新的访问令牌（Access Token）
   - Token description: `GitHub Actions - Dify SSO`
   - 权限: 选择 **Read, Write, Delete**
4. 复制生成的令牌（只显示一次，请保存好）

### 步骤 2: 在 GitHub 仓库中添加 Secrets

1. 进入你的 GitHub 仓库
2. 点击 **Settings** > **Secrets and variables** > **Actions**
3. 点击 **New repository secret**
4. 添加以下两个 secrets：

   **Secret 1: `DOCKERHUB_USERNAME`**
   - Name: `DOCKERHUB_USERNAME`
   - Value: 你的 Docker Hub 用户名

   **Secret 2: `DOCKERHUB_TOKEN`**
   - Name: `DOCKERHUB_TOKEN`
   - Value: 步骤 1 中创建的 Access Token

### 步骤 3: 验证配置

配置完成后，GitHub Actions 会自动：
- ✅ 登录到 Docker Hub
- ✅ 推送镜像到 Docker Hub（与 GitHub Container Registry 并行）
- ✅ 使用标签格式：`<username>/dify-{api,web,worker}:<version>` 和 `:latest`

## 📦 镜像命名规则

推送的镜像将使用以下命名格式：

```
docker.io/<DOCKERHUB_USERNAME>/dify-api:<VERSION>
docker.io/<DOCKERHUB_USERNAME>/dify-api:latest
docker.io/<DOCKERHUB_USERNAME>/dify-web:<VERSION>
docker.io/<DOCKERHUB_USERNAME>/dify-web:latest
docker.io/<DOCKERHUB_USERNAME>/dify-worker:<VERSION>
docker.io/<DOCKERHUB_USERNAME>/dify-worker:latest
```

其中：
- `<DOCKERHUB_USERNAME>`: 从 secret `DOCKERHUB_USERNAME` 读取，或默认为 GitHub 用户名
- `<VERSION>`: 从上游 Dify 版本号获取（例如：`1.9.2`）

## 🔍 验证镜像推送

推送成功后，你可以在以下位置查看：

1. **GitHub Container Registry**:
   - `ghcr.io/<github_owner>/dify-api:latest`
   - `ghcr.io/<github_owner>/dify-web:latest`
   - `ghcr.io/<github_owner>/dify-worker:latest`

2. **Docker Hub**:
   - `https://hub.docker.com/r/<username>/dify-api`
   - `https://hub.docker.com/r/<username>/dify-web`
   - `https://hub.docker.com/r/<username>/dify-worker`

## 🚨 故障排除

### 问题：推送失败，认证错误
- 检查 `DOCKERHUB_USERNAME` 和 `DOCKERHUB_TOKEN` secrets 是否正确配置
- 确认 Docker Hub Access Token 未过期
- 检查 Token 权限是否包含 Write 权限

### 问题：镜像未出现在 Docker Hub
- 检查 GitHub Actions 日志是否有错误
- 确认 Docker Hub 仓库名称是否正确（应为 `dify-api`, `dify-web`, `dify-worker`）
- 检查是否有权限创建新仓库

### 问题：只想推送到 Docker Hub，不想推送到 GitHub Container Registry
修改 `.github/workflows/sync-dify.yml`，移除或注释掉 GitHub Container Registry 相关步骤。

## 📝 注意事项

1. **访问令牌安全**: 
   - 不要在代码中硬编码访问令牌
   - 定期轮换访问令牌
   - 使用最小权限原则

2. **镜像大小**:
   - Docker Hub 对免费账户有拉取速率限制
   - 考虑使用 Docker Hub Pro 以提升性能

3. **多架构支持**:
   - 当前配置支持 `linux/amd64` 和 `linux/arm64`
   - 多架构镜像会增加构建时间

## 🔗 相关链接

- [Docker Hub 文档](https://docs.docker.com/docker-hub/)
- [GitHub Actions Docker 登录](https://github.com/docker/login-action)

