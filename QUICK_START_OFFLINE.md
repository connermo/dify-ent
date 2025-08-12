# 🚀 Dify 离线升级快速开始指南

## 🎯 你的情况

- ✅ Dify 服务器需要升级
- ❌ 无法连接互联网
- ✅ 需要应用 SSO 补丁
- ✅ 需要生成新的永久镜像

## 🚀 快速解决方案

### 方案一：一键创建离线升级包（推荐）

```bash
# 1. 在有网络的环境中
git clone https://github.com/your-username/dify-ent.git
cd dify-ent

# 2. 确保已下载官方 Dify 镜像
docker pull langgenius/dify-api:latest
docker pull langgenius/dify-web:latest

# 3. 运行离线升级脚本
./scripts/offline-upgrade-and-patch.sh
```

### 方案二：快速构建离线镜像

```bash
# 1. 在有网络的环境中
git clone https://github.com/your-username/dify-ent.git
cd dify-ent

# 2. 运行离线镜像构建脚本
./scripts/build-offline-images.sh
```

## 📦 生成的升级包

### 完整离线升级包
```
dify-offline-upgrade-20241201/
├── dify-api-sso.tar          # API 镜像
├── dify-web-sso.tar          # Web 镜像
├── UPGRADE_README.md         # 详细说明
└── quick-upgrade.sh          # 一键升级脚本
```

### 简化离线镜像包
```
dify-sso-images-20241201/
├── dify-api-sso.tar          # API 镜像
├── dify-web-sso.tar          # Web 镜像
├── deploy.sh                  # 部署脚本
├── env.example               # 环境变量示例
└── docker-compose.sso.yaml   # 配置文件
```

## 🔄 传输到目标服务器

```bash
# 使用 scp 传输
scp -r dify-offline-upgrade-20241201/ user@server:/opt/

# 或使用 rsync
rsync -avz dify-sso-images-20241201/ user@server:/opt/
```

## 🚀 在目标服务器上部署

### 使用完整升级包
```bash
cd /opt/dify-offline-upgrade-20241201
./quick-upgrade.sh
# 脚本会提供三种升级方式选择
```

### 使用简化镜像包
```bash
cd /opt/dify-sso-images-20241201
./deploy.sh

# 选择部署方式：
# 方案 1: 使用新镜像名称
docker compose -f docker-compose.sso.yaml up -d

# 方案 2: 保持原有镜像名称（仅添加环境变量）
docker compose -f docker-compose.keep-image.yaml up -d
```

## 🔧 必需的环境变量

```bash
# SSO 认证开关
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Keycloak 配置
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify

# 用户权限
ALLOW_REGISTER=true
ALLOW_CREATE_WORKSPACE=true
```

## 🔄 两种配置方式对比

### 方式 1: 修改镜像名称（推荐）
- ✅ **优点**: 完全控制，确保功能正常
- ✅ **优点**: 新镜像包含所有 SSO 补丁
- ✅ **优点**: 可以独立版本管理
- ❌ **缺点**: 需要修改 docker-compose.yaml

**适用场景**: 新部署、重大升级、需要完全控制

### 方式 2: 保持原有镜像名称
- ✅ **优点**: 不需要修改镜像名称
- ✅ **优点**: 配置变更最小
- ❌ **缺点**: 需要确保原有镜像已包含 SSO 补丁
- ❌ **缺点**: 依赖原有镜像的完整性

**适用场景**: 小规模配置变更、测试环境、原有镜像已包含补丁

## 📋 检查清单

### 准备阶段（有网络环境）
- [ ] 下载官方 Dify 镜像
- [ ] 克隆 dify-ent 仓库
- [ ] 运行离线升级脚本
- [ ] 验证升级包完整性

### 传输阶段
- [ ] 将升级包传输到目标服务器
- [ ] 验证文件完整性
- [ ] 检查磁盘空间

### 部署阶段（目标服务器）
- [ ] 加载 Docker 镜像
- [ ] 配置环境变量
- [ ] 更新 docker-compose.yaml
- [ ] 启动服务
- [ ] 验证 SSO 功能

## 🆘 遇到问题？

1. **查看详细文档**: `docs/offline-upgrade-solution.md`
2. **检查容器日志**: `docker compose logs -f`
3. **验证环境变量**: `docker compose exec api env`
4. **检查服务状态**: `docker compose ps`

## 💡 提示

- 建议先在测试环境中验证升级包
- 保留原始镜像的备份
- 记录升级过程中的关键步骤
- 准备回滚方案

---

**快速开始**: 运行 `./scripts/offline-upgrade-and-patch.sh` 即可创建完整的离线升级包！
