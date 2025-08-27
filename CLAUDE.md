# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Dify Enterprise SSO**, a complete solution that integrates the open-source Dify AI platform (https://github.com/langgenius/dify.git) with Keycloak for Single Sign-On (SSO) authentication using OAuth2/OpenID Connect. The project automatically syncs with upstream Dify releases and applies enterprise authentication patches. Currently based on Dify v1.7.2.

## Key Architecture

- **Base Platform**: Official Dify repository (langgenius/dify) with integrated SSO patches
- **Authentication**: Keycloak OAuth2/OIDC integration for enterprise SSO
- **Data Encryption**: PostgreSQL transparent encryption solution
- **Log Management**: Conversation log cleanup functionality
- **Patch Management**: Modular feature patch system
- **Deployment**: Docker Compose setup using official Dify configuration
- **Development**: Direct integration into dify/ directory for easy upstream sync

## Development Environment Setup

### Prerequisites
Before starting development, ensure you have the following installed:
- **CPU**: >= 2 cores
- **RAM**: >= 4 GiB  
- **Python**: 3.12
- **Node.js**: v22 (LTS)
- **PNPM**: v10
- **Docker** and **Docker Compose**
- **Optional**: FFmpeg for OpenAI TTS

### Alternative Development Workflow (简化版本)
For rapid development, you can also use these simplified commands:

**步骤 1: 启动基础设施**
```bash
# 在 dify/docker 目录下
cd dify/docker
cp middleware.env.example middleware.env
docker compose -f docker-compose.middleware.yaml up -d
```

**步骤 2: 启动后端 API**
```bash
# 在 dify 目录下
./dev/start-api
```

**步骤 3: 启动前端开发服务器**
```bash
# 在 dify/web 目录下
cd dify/web
pnpm start
```

**步骤 4: (可选) 启动 Keycloak SSO**
```bash
# 在项目根目录
cd keycloak
docker compose up -d
```

### Local Source Code Development (根据官方文档)

#### 1. 环境准备和中间件启动
```bash
# Clone repository (if not already done)
git clone https://github.com/langgenius/dify.git

# Start middleware services (Redis, PostgreSQL, etc.)
cd docker
cp middleware.env.example middleware.env
docker compose -f docker-compose.middleware.yaml up -d
```

#### 2. 后端服务 (API) 开发
```bash
cd api
cp .env.example .env

# 生成随机 SECRET_KEY 并配置环境变量
# Generate SECRET_KEY: openssl rand -base64 42

# Install dependencies and setup database
uv sync
uv run flask db upgrade

# Start API server in development mode
uv run flask run --host 0.0.0.0 --port=5001 --debug
```

#### 3. Worker 服务启动
```bash
# In a new terminal, start Celery worker
cd api
uv run celery -A app.celery worker -P gevent -c 1 --loglevel INFO
```

#### 4. Web 前端服务开发
```bash
cd web
pnpm install --frozen-lockfile
cp .env.example .env.local

# Build and start web service
pnpm build
pnpm start
```

#### 5. 访问应用
- **Web Console**: http://127.0.0.1:3000
- **API Endpoint**: http://127.0.0.1:5001

### Enterprise SSO Development Workflow
For this enterprise SSO version, additional steps are required:

```bash
# Start Keycloak first for SSO setup
cd keycloak && docker compose up -d

# For containerized development (alternative to source code)
cd dify && docker compose up -d

# Restart API service after code changes
cd dify && docker compose restart api

# View logs
cd dify && docker compose logs -f api
cd keycloak && docker compose logs -f keycloak
```

## Building and Testing

### Source Code Development Testing
```bash
# Database migrations (source code mode)
cd api
uv run flask db upgrade

# API health check
curl -f http://localhost:5001/health

# Frontend build verification
cd web
pnpm build
```

### Container Development Testing  
```bash
# Build and restart services
cd dify && docker compose build api && docker compose restart api

# Test Keycloak configuration
curl -f http://localhost:8280/realms/dify/.well-known/openid-configuration

# Test Dify API health  
curl -f http://localhost:5001/health
```

### Development Best Practices
```bash
# Recommended: Use pyenv to manage Python versions
pyenv install 3.12
pyenv local 3.12

# Install uv for fast Python dependency management
curl -LsSf https://astral.sh/uv/install.sh | sh

# Keep dependencies up to date
cd api && uv sync --upgrade
cd web && pnpm install --frozen-lockfile
```

### Service Management and Recompilation Requirements
- **API 修改**: If API code is modified and the API service is already running, no restart is needed - it will auto-reload
- **Web 修改**: For web code changes, go to `dify/web` and run `pnpm build` to compile, then restart
- **配置修改**: Restart related Docker containers for configuration changes

### Database Management
```bash
# Database migrations
cd dify && docker compose exec api python -m flask db upgrade

# Access database
cd dify && docker compose exec db psql -U postgres -d dify
```

## Architecture & Structure

### Core Components
1. **dify/**: Official Dify repository with integrated SSO modifications
   - `api/libs/oauth.py`: OAuth providers including KeycloakOAuth class
   - `api/configs/feature/__init__.py`: Keycloak configuration fields
   - `api/controllers/console/auth/oauth.py`: OAuth endpoint handlers
   - `docker/docker-compose.yaml`: Complete service orchestration
   
2. **keycloak/**: Keycloak identity provider setup
   - `realm-dify.json`: Pre-configured realm with test users
   - `docker-compose.yml`: Keycloak service configuration

### Key Integration Points
- **OAuth Flow**: `dify/api/controllers/console/auth/oauth.py:103-115`
- **Config Management**: `dify/api/configs/feature/__init__.py:606-618`
- **KeycloakOAuth Class**: `dify/api/libs/oauth.py:140-214`
- **Docker Services**: `dify/docker/docker-compose.yaml`

### Environment Configuration
The system uses a hybrid configuration approach:
- **Base Config**: `.env` file with Dify standard settings
- **SSO Config**: Keycloak-specific variables in docker-compose
- **Runtime Config**: Auto-generated from environment templates

Key SSO environment variables:
```bash
ENABLE_SOCIAL_OAUTH_LOGIN=true
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
```

## Automated Upstream Sync

The project automatically maintains compatibility with upstream Dify through GitHub Actions:

### GitHub Actions Workflow Features
1. **Automatic Release Detection**: Monitors langgenius/dify for new releases daily
2. **Smart SSO Integration**: Applies Keycloak patches automatically using `scripts/apply-sso-integration.sh`
3. **Multi-Architecture Builds**: Creates Docker images for linux/amd64 and linux/arm64
4. **Automated Releases**: Creates GitHub releases with Docker images

### Manual Sync Process
```bash
# Test SSO integration after manual changes
./scripts/test-sso-integration.sh

# Apply SSO integration to fresh Dify checkout
./scripts/apply-sso-integration.sh

# Manual sync workflow
cd dify && git fetch origin && git checkout <version-tag>
cd .. && ./scripts/apply-sso-integration.sh
```

### Workflow Triggers
- **Automatic**: Daily check for upstream releases
- **Manual**: Workflow dispatch with options for force sync and multi-arch builds
- **Push**: Changes to workflow file or dify/ directory

## Development Guidelines

### Enterprise Development Workflow (开发工作流程)

#### Code Modification Process (代码修改流程)
1. **重置到基线版本**: `git -C dify checkout $(cat VERSION.txt)`  # 不带 v 前缀
2. **应用现有补丁**: Apply patches from `patches/` directory as needed
3. **进行代码修改**: Make code changes in `dify/` directory
4. **测试验证**: Restart related services for testing
5. **生成补丁**: Create `.patch` files for stable changes
6. **补丁管理**: Save patch files to `patches/` directory

#### Important Conventions (重要约定)
- ❌ **Never commit `dify/` directory to Git**
- ✅ Only commit patch files, scripts, and documentation
- ✅ Maintain patches separately for each feature module
- ✅ Patch file naming: `功能名-描述.patch`
- ✅ Keep only one patch file per feature
- ✅ Delete test files after testing

#### Patch Management (补丁管理)
```bash
# Dify source code management
git -C dify fetch origin
git -C dify checkout $(cat VERSION.txt)  # 不带 v 前缀

# View current version
cat VERSION.txt

# Generate patch
git -C dify diff > patches/新功能名.patch

# Apply patch
git -C dify apply ../patches/功能名.patch
```

#### Development Notes (开发注意事项)
1. **版本同步**: Always develop based on the Dify version specified in VERSION.txt
2. **补丁隔离**: Different feature patches should be independent for separate application
3. **测试完备性**: Any patch must be thoroughly tested before generation
4. **文档更新**: Don't write summary docs every time, only when needed for submission

### Working with OAuth Integration
- OAuth providers are dynamically loaded based on environment config
- Test users: `alice/alice1234` in Keycloak realm
- Keycloak admin: `admin/admin` at `http://localhost:8280/admin`

### Code Modifications
- **API Changes**: Edit files directly in `dify/api/` directory
- **Web Changes**: Modify files in `dify/web/` directory
- **Configuration**: Update environment variables and docker-compose settings

### Testing SSO Integration
1. Start Keycloak: `cd keycloak && docker compose up -d`
2. Start Dify services: `cd dify && docker compose up -d`
3. Access Dify Console: `http://localhost:3000`
4. Click "Login with Keycloak" button
5. Authenticate with test user credentials

### Troubleshooting Common Issues
- **OAuth not visible**: Check `ENABLE_SOCIAL_OAUTH_LOGIN=true` in environment
- **Keycloak connection**: Verify `KEYCLOAK_ISSUER_URL` matches running instance
- **User creation fails**: Check Keycloak realm configuration and user settings
- **Build failures**: Ensure patches apply cleanly to current upstream version

## File Structure Context

```
/
├── dify/                    # Dify 官方源码 (不提交到 Git)
├── patches/                 # 功能补丁存储目录
├── scripts/                 # 自动化脚本
├── docs/                    # 技术文档
├── keycloak/               # SSO 服务配置
├── nginx/                  # Reverse proxy configuration templates (legacy)
├── ssrf_proxy/             # SSRF protection proxy configuration (legacy)
├── volumes/                # Persistent data storage for services
├── VERSION.txt             # 当前基于的 Dify 版本 (1.7.2)
└── CLAUDE.md               # Project documentation and development guidelines
```

### Key Files and Directories
- **`dify/`**: Official Dify repository with integrated SSO modifications (**NEVER commit to Git**)
- **`patches/`**: Feature patch storage directory
  - `clear-logs-with-files-complete.patch`: Complete log cleanup functionality
  - `dify-encryption-ultra-minimal.patch`: Minimal data encryption solution
- **`scripts/`**: Automation scripts
  - `apply-sso-integration.sh`: Auto-apply SSO integration patches
  - `build-local-images.sh`: Build local Docker images
  - `offline-upgrade-and-patch.sh`: Offline upgrade and patch application
- **`keycloak/`**: Keycloak identity provider configuration and data
  - `realm-dify.json`: Pre-configured realm with test users
  - `docker-compose.yml`: Keycloak service configuration
- **`docs/`**: Technical documentation for various features
- **`VERSION.txt`**: Current Dify version base (1.7.2)

## Enterprise Features

This build includes enterprise-ready features:
- **SSO Integration**: Keycloak OAuth2/OIDC single sign-on integration
- **Data Encryption**: PostgreSQL transparent encryption solution  
- **Log Management**: Conversation log cleanup functionality
- **Patch Management**: Modular feature patch system
- **Multi-tenant SSO**: Keycloak realm-based organization separation
- **HTTPS Support**: Nginx SSL termination with Let's Encrypt integration
- **High Availability**: Redis clustering and PostgreSQL optimization
- **Monitoring**: Built-in logging and health check endpoints
- **Security**: SSRF protection proxy and secure defaults