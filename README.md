# Dify Enterprise SSO (本地 Keycloak 集成)

本仓库提供了一个完整的解决方案，用于将 Dify Console 与本地 Keycloak OAuth2/OpenID Connect (OIDC) 服务器集成，实现单点登录 (SSO) 认证。


## 🚀 快速开始

### 1. 启动 Keycloak 服务器

```bash
cd keycloak
docker compose up -d
```

等待 Keycloak 准备就绪（检查日志）：
```bash
docker compose logs -f keycloak
```

**预期访问地址：**
- Keycloak 管理界面: http://localhost:8280/admin
- Dify 域: http://localhost:8280/realms/dify
- OpenID 配置: http://localhost:8280/realms/dify/.well-known/openid-configuration

**默认凭据：**
- 管理员: `admin` / `admin`
- 测试用户: `alice` / `alice1234`

### 2. 应用 SSO 集成到 Dify

#### 方案 A: 使用自动化脚本（推荐）
```bash
# 运行 SSO 集成脚本
./scripts/apply-sso-integration.sh
```

此脚本将：
- ✅ 添加 Keycloak 配置字段
- ✅ 添加支持 PKCE 的 KeycloakOAuth 类
- ✅ 更新 OAuth 控制器以集成 Keycloak
- ✅ 添加 OAuth 提供商 API 端点
- ✅ 更新 docker-compose.yaml 以包含 SSO 环境变量
- ✅ 更新前端以显示 'SSO' 而不是 'Keycloak'
- ✅ 创建包含默认 SSO 配置的 .env 文件

#### 方案 B: 手动代码修改
手动进入镜像修改以下文件：
- `api/configs/feature/__init__.py` - 添加 Keycloak 配置字段
- `api/libs/oauth.py` - 添加 KeycloakOAuth 类
- `api/controllers/console/auth/oauth.py` - 注册 Keycloak 提供商
- `web/app/signin/components/social-auth.tsx` - 添加登录按钮

### 3. 配置环境变量

#### 必需的 SSO 环境变量

在您的 Dify 服务中添加以下环境变量：

```bash
# SSO 认证开关
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Keycloak OAuth 配置
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify

# Dify 服务地址配置
CONSOLE_API_URL=http://localhost:5001
CONSOLE_WEB_URL=http://localhost:3000

# 用户注册和工作空间权限
ALLOW_REGISTER=true
ALLOW_CREATE_WORKSPACE=true
```

#### 完整的 .env 文件示例

```bash
# SSO 配置
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Keycloak OAuth 设置
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify

# Dify 服务地址
CONSOLE_API_URL=http://localhost:5001
CONSOLE_WEB_URL=http://localhost:3000

# 用户权限设置
ALLOW_REGISTER=true
ALLOW_CREATE_WORKSPACE=true

# 其他可选配置
ENABLE_SIGNUP=true
ENABLE_OAUTH_LOGIN=true
```

#### Docker Compose 环境变量配置

在 `docker-compose.yaml` 中的 `api` 服务下添加：

```yaml
services:
  api:
    environment:
      # SSO 认证开关
      - ENABLE_SOCIAL_OAUTH_LOGIN=true
      
      # Keycloak 配置
      - KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-dify-console}
      - KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-dify-console-secret}
      - KEYCLOAK_ISSUER_URL=${KEYCLOAK_ISSUER_URL:-http://localhost:8280/realms/dify}
      
      # Dify 服务地址
      - CONSOLE_API_URL=${CONSOLE_API_URL:-http://localhost:5001}
      - CONSOLE_WEB_URL=${CONSOLE_WEB_URL:-http://localhost:3000}
      
      # 用户权限
      - ALLOW_REGISTER=${ALLOW_REGISTER:-true}
      - ALLOW_CREATE_WORKSPACE=${ALLOW_CREATE_WORKSPACE:-true}
```

### 4. 启动服务

```bash
# 启动所有服务
docker compose up -d

# 检查服务状态
docker compose ps

# 查看日志
docker compose logs -f
```