# SSO Integration Patches - Keycloak OAuth2/OIDC

本文档说明如何使用 SSO 集成补丁将 Keycloak 单点登录功能集成到 Dify 中。

## 📋 补丁文件列表

### 后端补丁
1. **`sso-config-feature.patch`** - 配置文件补丁
   - 添加 Keycloak OAuth 配置字段到 `api/configs/feature/__init__.py`
   - 添加 `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`, `KEYCLOAK_ISSUER_URL` 配置项

2. **`sso-libs-oauth.patch`** - OAuth 库补丁
   - 添加 `KeycloakOAuth` 类到 `api/libs/oauth.py`
   - 实现 PKCE (Proof Key for Code Exchange) 支持
   - 包含 OAuth2/OIDC 认证流程

3. **`sso-controller-oauth.patch`** - OAuth 控制器补丁
   - 更新 `api/controllers/console/auth/oauth.py`
   - 添加 Keycloak provider 支持
   - 添加 `/oauth/providers` API 端点
   - 实现 PKCE 状态参数解析

### 前端补丁
4. **`sso-web-social-auth.patch`** - 社交登录组件补丁
   - 更新 `web/app/signin/components/social-auth.tsx`
   - 添加 `providers` prop 支持条件渲染
   - 添加 SSO 登录按钮，使用 `RiUserLine` 图标

5. **`sso-web-normal-form.patch`** - 登录表单补丁
   - 更新 `web/app/signin/normal-form.tsx`
   - 添加从后端获取可用 OAuth providers 的逻辑
   - 传递 providers 到 SocialAuth 组件

### Docker 配置补丁
6. **`sso-docker-compose.patch`** - Docker Compose 配置补丁
   - 更新 `docker/docker-compose.yaml`
   - 添加 SSO 相关环境变量到共享配置

## 🚀 使用方法

### 方法 1: 使用自动化脚本（推荐）

```bash
# 从项目根目录运行
./scripts/apply-sso-integration.sh
```

这个脚本会自动应用所有必要的更改。

### 方法 2: 手动应用补丁

```bash
# 进入 dify 目录
cd dify

# 初始化 git 仓库（如果还没有）
git init
git add .
git commit -m "Initial commit"

# 应用后端补丁
git apply ../patches/sso-config-feature.patch
git apply ../patches/sso-libs-oauth.patch
git apply ../patches/sso-controller-oauth.patch

# 应用前端补丁
git apply ../patches/sso-web-social-auth.patch
git apply ../patches/sso-web-normal-form.patch

# 应用 Docker 配置补丁
git apply ../patches/sso-docker-compose.patch
```

## ⚙️ 环境变量配置

在 `dify/docker/.env` 或 `dify/docker/docker-compose.yaml` 中添加：

```bash
# 启用社交登录
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Keycloak 配置
KEYCLOAK_CLIENT_ID=your-client-id
KEYCLOAK_CLIENT_SECRET=your-client-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify

# Console URLs
CONSOLE_API_URL=http://localhost
CONSOLE_WEB_URL=http://localhost
```

## 🔍 验证安装

1. **验证后端配置**：
```bash
cd dify/api
python3 -c "from configs.feature import FeatureConfig; print(hasattr(FeatureConfig, 'KEYCLOAK_CLIENT_ID'))"
```

2. **验证 OAuth Providers API**：
```bash
curl http://localhost/console/api/oauth/providers
# 应该返回: {"providers": {"github": false, "google": false, "keycloak": true}}
```

3. **验证前端**：
- 访问登录页面，应该能看到 "使用 SSO 登录" 按钮
- 按钮应该显示用户图标（RiUserLine）

## 📝 功能特性

- ✅ Keycloak OAuth2/OIDC 集成
- ✅ PKCE (Proof Key for Code Exchange) 支持
- ✅ 可配置的 OAuth providers 显示
- ✅ 动态获取可用 providers
- ✅ 用户友好的 SSO 登录按钮
- ✅ Docker Compose 环境变量支持

## 🔧 故障排除

### 问题：SSO 按钮不显示
- 检查 `ENABLE_SOCIAL_OAUTH_LOGIN=true` 已设置
- 检查 Keycloak 配置是否正确
- 检查浏览器控制台是否有 JavaScript 错误

### 问题：OAuth 登录失败
- 检查 Keycloak 服务是否运行
- 检查 `KEYCLOAK_ISSUER_URL` 是否正确
- 检查 Keycloak client 配置是否正确

### 问题：补丁应用失败
- 确保 Dify 版本与补丁兼容（当前：v1.9.2）
- 尝试清理并重新应用补丁
- 检查是否有未提交的更改冲突

## 🔄 更新补丁

如果需要更新补丁文件：

```bash
cd dify
git diff api/configs/feature/__init__.py > ../patches/sso-config-feature.patch
# ... 对其他文件重复
```

## 📚 相关文档

- [Keycloak 配置指南](../keycloak/README.md)
- [Dify SSO 集成文档](../docs/WEB_PATCH_LOGIC.md)

