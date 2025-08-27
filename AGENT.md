# Dify 企业级扩展项目 - AI 开发助手指南

## 📋 项目概述
这是一个基于开源 Dify 项目 (https://github.com/langgenius/dify.git) 的企业级功能扩展项目，当前基于 Dify v1.7.2 版本。

### 核心功能模块
- **SSO 集成**: Keycloak OAuth2/OIDC 单点登录集成
- **数据加密**: PostgreSQL 透明加密解决方案  
- **日志管理**: 对话日志清理功能
- **补丁管理**: 模块化功能补丁系统

### 项目结构
```
/
├── dify/                    # Dify 官方源码 (不提交到 Git)
├── patches/                 # 功能补丁存储目录
├── scripts/                 # 自动化脚本
├── docs/                    # 技术文档
├── keycloak/               # SSO 服务配置
└── VERSION.txt             # 当前基于的 Dify 版本 (1.7.2)
```

## 🚀 开发环境设置

### 前置条件
- Docker & Docker Compose
- Node.js & pnpm (前端开发)
- Python 3.x (API 开发)

### 启动开发环境

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

## 🔧 开发工作流程

### 代码修改流程
1. **重置到基线版本**: `git -C dify checkout VERSION.txt中的版本号`
2. **应用现有补丁**: 根据需要应用 `patches/` 目录中的补丁
3. **进行代码修改**: 在 `dify/` 目录中修改源码
4. **测试验证**: 重启相关服务进行测试
5. **生成补丁**: 将稳定的修改生成为 `.patch` 文件
6. **补丁管理**: 将补丁文件保存到 `patches/` 目录

### 重要约定
- ❌ **绝对不要提交 `dify/` 目录到 Git**
- ✅ 只提交补丁文件、脚本和文档
- ✅ 每个功能模块单独维护补丁文件
- ✅ 补丁文件命名规范: `功能名-描述.patch`
- ✅ 每个功能只保留一个补丁文件
- ✅ 测试后删除测试文件

### 重新编译要求
- **API 修改**: 重启 `./dev/start-api`
- **Web 修改**: 在 `dify/web` 目录运行 `pnpm build`
- **配置修改**: 重启相关 Docker 容器

## 📦 关键文件说明

### 补丁文件 (`patches/`)
- `clear-logs-with-files-complete.patch`: 完整的日志清理功能
- `dify-encryption-ultra-minimal.patch`: 极简数据加密方案

### 脚本文件 (`scripts/`)
- `apply-sso-integration.sh`: 自动应用 SSO 集成补丁
- `build-local-images.sh`: 构建本地 Docker 镜像
- `offline-upgrade-and-patch.sh`: 离线升级和补丁应用

### 技术文档 (`docs/`)
- 各种功能的详细实现文档和技术分析

## 🔍 常用命令参考

### Dify 源码管理
```bash
# 获取官方源码 (在 dify 目录下)
git fetch origin
git checkout $(cat ../VERSION.txt)  # 不带 v 前缀

# 查看当前版本
cat VERSION.txt
```

### 补丁操作
```bash
# 生成补丁
git -C dify diff > patches/新功能名.patch

# 应用补丁  
git -C dify apply ../patches/功能名.patch
```

### 服务管理
- 如果是修改了api代码，而且api服务已经启动的话，不需要重新启动api服务，它会自动更新。
- 如果修改了web代码，需要进入dify/web，运行 pnpm build 编译后重新启动。

## ⚠️ 开发注意事项

1. **版本同步**: 始终基于 VERSION.txt 中指定的 Dify 版本进行开发
2. **补丁隔离**: 不同功能的补丁应该相互独立，便于单独应用
3. **测试完备性**: 任何补丁在生成前都必须经过充分测试
4. **文档更新**: 不要每次都写总结文档，需要提交的时候再写。

