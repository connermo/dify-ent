#!/bin/bash

# 离线升级 Dify 并应用 SSO 补丁脚本
# 适用于无法连接互联网的生产环境

set -e

echo "🚀 离线升级 Dify 并应用 SSO 补丁..."

# 检查是否在正确的目录
if [ ! -d "dify" ]; then
    echo "❌ 错误: dify 目录未找到。请从项目根目录运行此脚本。"
    exit 1
fi

cd dify

# 检查是否有现有的 Dify 容器
echo "📋 检查现有 Dify 容器..."
EXISTING_CONTAINERS=$(docker ps -a --filter "name=dify" --format "{{.Names}}" 2>/dev/null || true)

if [ -n "$EXISTING_CONTAINERS" ]; then
    echo "⚠️  发现现有 Dify 容器:"
    echo "$EXISTING_CONTAINERS"
    echo ""
    read -p "是否要停止并备份现有容器？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🛑 停止现有容器..."
        docker stop $(docker ps -q --filter "name=dify") 2>/dev/null || true
        
        echo "💾 备份现有容器..."
        docker commit $(docker ps -aq --filter "name=dify") dify-backup-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
        echo "✅ 备份完成"
    fi
fi

echo ""
echo "📦 步骤 1: 准备离线升级包..."

# 创建升级包目录
UPGRADE_DIR="../dify-offline-upgrade-$(date +%Y%m%d)"
mkdir -p "$UPGRADE_DIR"

echo "📁 创建升级包目录: $UPGRADE_DIR"

# 检查是否有现有的 Dify 镜像
echo "🔍 检查现有 Dify 镜像..."
EXISTING_IMAGES=$(docker images --filter "reference=langgenius/dify*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)

if [ -n "$EXISTING_IMAGES" ]; then
    echo "📋 发现现有 Dify 镜像:"
    echo "$EXISTING_IMAGES"
    echo ""
    read -p "是否要使用现有镜像作为基础？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "✅ 将使用现有镜像作为基础"
        BASE_API_IMAGE=$(echo "$EXISTING_IMAGES" | grep "api" | head -1)
        BASE_WEB_IMAGE=$(echo "$EXISTING_IMAGES" | grep "web" | head -1)
        
        if [ -z "$BASE_API_IMAGE" ] || [ -z "$BASE_WEB_IMAGE" ]; then
            echo "❌ 未找到完整的 API 和 Web 镜像"
            exit 1
        fi
        
        echo "📦 基础 API 镜像: $BASE_API_IMAGE"
        echo "📦 基础 Web 镜像: $BASE_WEB_IMAGE"
    else
        echo "❌ 需要先在有网络的环境中下载官方镜像"
        exit 1
    fi
else
    echo "❌ 未找到现有 Dify 镜像"
    echo "💡 提示: 请先在有网络的环境中运行以下命令下载镜像："
    echo "   docker pull langgenius/dify-api:latest"
    echo "   docker pull langgenius/dify-web:latest"
    echo "   然后使用 docker save 导出镜像文件"
    exit 1
fi

echo ""
echo "🔧 步骤 2: 应用 SSO 补丁..."

# 检查是否有补丁文件
if [ -f "../dify-keycloak.diff" ]; then
    echo "📋 发现补丁文件: ../dify-keycloak.diff"
    echo "🔧 应用补丁到代码库..."
    git apply ../dify-keycloak.diff
    echo "✅ 补丁应用完成"
else
    echo "⚠️  未找到补丁文件，将使用脚本方式应用更改..."
    
    # 运行 SSO 集成脚本
    if [ -f "../scripts/apply-sso-integration.sh" ]; then
        echo "🔧 运行 SSO 集成脚本..."
        bash ../scripts/apply-sso-integration.sh
    else
        echo "❌ 未找到 SSO 集成脚本"
        exit 1
    fi
fi

echo ""
echo "🐳 步骤 3: 构建新的 Docker 镜像..."

# 创建 Dockerfile 用于构建新镜像
echo "📝 创建 API 服务的 Dockerfile..."
cat > Dockerfile.api << 'EOF'
FROM langgenius/dify-api:latest

# 复制修改后的代码
COPY api/ /app/api/
COPY docker/ /app/docker/

# 设置工作目录
WORKDIR /app

# 安装补丁工具（如果需要）
RUN apt-get update && apt-get install -y patch && rm -rf /var/lib/apt/lists/*

# 应用任何额外的补丁
RUN if [ -f /app/patches/api.patch ]; then \
        patch -p1 < /app/patches/api.patch; \
    fi

# 重新构建 Python 包（如果需要）
RUN cd api && pip install -r requirements.txt

EXPOSE 5001
CMD ["python", "api/run.py"]
EOF

echo "📝 创建 Web 服务的 Dockerfile..."
cat > Dockerfile.web << 'EOF'
FROM langgenius/dify-web:latest

# 复制修改后的代码
COPY web/ /app/web/
COPY docker/ /app/docker/

# 设置工作目录
WORKDIR /app

# 安装依赖并构建
RUN cd web && npm install && npm run build

EXPOSE 3000
CMD ["npm", "start"]
EOF

echo "🔨 构建 API 镜像..."
docker build -t dify-api-sso:latest -f Dockerfile.api .

echo "🔨 构建 Web 镜像..."
docker build -t dify-web-sso:latest -f Dockerfile.web .

echo ""
echo "💾 步骤 4: 保存新镜像到文件..."

# 保存新镜像到文件
echo "📦 保存 API 镜像..."
docker save dify-api-sso:latest -o "$UPGRADE_DIR/dify-api-sso.tar"

echo "📦 保存 Web 镜像..."
docker save dify-web-sso:latest -o "$UPGRADE_DIR/dify-web-sso.tar"

echo ""
echo "📋 步骤 5: 创建升级说明文档..."

# 创建升级说明
cat > "$UPGRADE_DIR/UPGRADE_README.md" << 'EOF'
# Dify SSO 升级包使用说明

## 📦 包含文件

- `dify-api-sso.tar` - 包含 SSO 集成的 API 服务镜像
- `dify-web-sso.tar` - 包含 SSO 集成的 Web 服务镜像
- `UPGRADE_README.md` - 本说明文档

## 🚀 升级步骤

### 1. 加载镜像

```bash
# 加载 API 镜像
docker load -i dify-api-sso.tar

# 加载 Web 镜像
docker load -i dify-web-sso.tar
```

### 2. 更新 docker-compose.yaml

#### 方案 A: 修改镜像名称（推荐）

```yaml
services:
  api:
    image: dify-api-sso:latest  # 修改为新的镜像名称
    environment:
      - ENABLE_SOCIAL_OAUTH_LOGIN=true
      - KEYCLOAK_CLIENT_ID=dify-console
      - KEYCLOAK_CLIENT_SECRET=dify-console-secret
      - KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
      - CONSOLE_API_URL=http://localhost:5001
      - CONSOLE_WEB_URL=http://localhost:3000
      - ALLOW_REGISTER=true
      - ALLOW_CREATE_WORKSPACE=true
  
  web:
    image: dify-web-sso:latest  # 修改为新的镜像名称
    # ... 其他配置
```

#### 方案 B: 保持原有镜像名称（仅添加环境变量）

如果你想保持原有的镜像名称不变，只需要添加环境变量：

```yaml
services:
  api:
    # 保持原有镜像名称不变
    # image: langgenius/dify-api:latest
    environment:
      # 添加以下 SSO 环境变量
      - ENABLE_SOCIAL_OAUTH_LOGIN=true
      - KEYCLOAK_CLIENT_ID=dify-console
      - KEYCLOAK_CLIENT_SECRET=dify-console-secret
      - KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
      - CONSOLE_API_URL=http://localhost:5001
      - CONSOLE_WEB_URL=http://localhost:3000
      - ALLOW_REGISTER=true
      - ALLOW_CREATE_WORKSPACE=true
      
      # 保留原有的其他环境变量
      # ... 其他配置
```

### 3. 启动服务

```bash
# 启动所有服务
docker compose up -d

# 检查服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

## 🔧 配置说明

### 必需的环境变量

- `ENABLE_SOCIAL_OAUTH_LOGIN=true` - 启用 SSO 登录
- `KEYCLOAK_CLIENT_ID` - Keycloak 客户端 ID
- `KEYCLOAK_CLIENT_SECRET` - Keycloak 客户端密钥
- `KEYCLOAK_ISSUER_URL` - Keycloak 发行者 URL
- `ALLOW_REGISTER=true` - 允许用户注册
- `ALLOW_CREATE_WORKSPACE=true` - 允许创建工作空间

## 🆘 故障排除

如果遇到问题，请检查：

1. 镜像是否正确加载
2. 环境变量是否正确设置
3. Keycloak 服务是否正常运行
4. 查看 Docker 日志获取详细错误信息

## 📅 升级信息

- 升级时间: $(date)
- 包含功能: SSO 集成、用户注册、工作空间创建
- 基础版本: 基于官方 Dify 镜像
EOF

echo ""
echo "📋 步骤 6: 创建快速升级脚本..."

# 创建快速升级脚本
cat > "$UPGRADE_DIR/quick-upgrade.sh" << 'EOF'
#!/bin/bash

# Dify SSO 快速升级脚本

set -e

echo "🚀 开始 Dify SSO 升级..."

# 检查镜像文件
if [ ! -f "dify-api-sso.tar" ] || [ ! -f "dify-web-sso.tar" ]; then
    echo "❌ 错误: 镜像文件未找到"
    exit 1
fi

# 加载镜像
echo "📦 加载 API 镜像..."
docker load -i dify-api-sso.tar

echo "📦 加载 Web 镜像..."
docker load -i dify-web-sso.tar

echo "✅ 镜像加载完成"

# 检查是否有 docker-compose.yaml
if [ -f "docker-compose.yaml" ]; then
    echo ""
    echo "📋 发现 docker-compose.yaml"
    echo "请选择升级方式："
    echo "1) 修改镜像名称（推荐）"
    echo "2) 保持原有镜像名称，仅添加环境变量"
    echo "3) 手动配置"
    echo ""
    read -p "请选择 (1-3): " choice
    
    case $choice in
        1)
            echo "🔧 方案 1: 修改镜像名称"
            echo "请将 docker-compose.yaml 中的镜像名称更新为："
            echo "  - api: dify-api-sso:latest"
            echo "  - web: dify-web-sso:latest"
            echo "并添加必要的环境变量"
            ;;
        2)
            echo "🔧 方案 2: 保持原有镜像名称"
            echo "请将以下环境变量添加到 docker-compose.yaml 的 api 服务中："
            echo ""
            echo "environment:"
            echo "  - ENABLE_SOCIAL_OAUTH_LOGIN=true"
            echo "  - KEYCLOAK_CLIENT_ID=dify-console"
            echo "  - KEYCLOAK_CLIENT_SECRET=dify-console-secret"
            echo "  - KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify"
            echo "  - CONSOLE_API_URL=http://localhost:5001"
            echo "  - CONSOLE_WEB_URL=http://localhost:3000"
            echo "  - ALLOW_REGISTER=true"
            echo "  - ALLOW_CREATE_WORKSPACE=true"
            echo ""
            echo "⚠️  注意: 此方案需要确保原有镜像已包含 SSO 补丁"
            ;;
        3)
            echo "🔧 方案 3: 手动配置"
            echo "请参考 UPGRADE_README.md 进行手动配置"
            ;;
        *)
            echo "❌ 无效选择，请手动配置"
            ;;
    esac
else
    echo "⚠️  未发现 docker-compose.yaml，请手动创建或配置"
fi

echo ""
echo "🎉 升级完成！"
echo "📋 下一步："
echo "1. 根据选择的方案更新 docker-compose.yaml"
echo "2. 添加必要的环境变量"
echo "3. 运行 'docker compose up -d' 启动服务"
echo ""
echo "📖 详细说明请查看 UPGRADE_README.md"
EOF

chmod +x "$UPGRADE_DIR/quick-upgrade.sh"

echo ""
echo "🎉 离线升级包创建完成！"
echo ""
echo "📁 升级包位置: $UPGRADE_DIR"
echo "📦 包含文件:"
echo "  - dify-api-sso.tar (API 镜像)"
echo "  - dify-web-sso.tar (Web 镜像)"
echo "  - UPGRADE_README.md (升级说明)"
echo "  - quick-upgrade.sh (快速升级脚本)"
echo ""
echo "🚀 使用方法:"
echo "1. 将整个 $UPGRADE_DIR 目录复制到目标服务器"
echo "2. 在目标服务器上运行: cd $UPGRADE_DIR && ./quick-upgrade.sh"
echo "3. 按照说明更新 docker-compose.yaml 并启动服务"
echo ""
echo "💡 提示: 此升级包包含了完整的 SSO 集成功能，"
echo "   包括用户注册和工作空间创建权限。"

cd ..
