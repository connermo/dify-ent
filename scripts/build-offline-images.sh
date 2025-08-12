#!/bin/bash

# 离线构建包含 SSO 补丁的 Dify 镜像
# 适用于无法连接互联网的环境

set -e

echo "🐳 离线构建 Dify SSO 镜像..."

# 检查是否在正确的目录
if [ ! -d "dify" ]; then
    echo "❌ 错误: dify 目录未找到。请从项目根目录运行此脚本。"
    exit 1
fi

cd dify

# 检查是否有现有的 Dify 镜像
echo "🔍 检查现有 Dify 镜像..."
EXISTING_IMAGES=$(docker images --filter "reference=langgenius/dify*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)

if [ -z "$EXISTING_IMAGES" ]; then
    echo "❌ 未找到现有 Dify 镜像"
    echo "💡 请先在有网络的环境中下载官方镜像："
    echo "   docker pull langgenius/dify-api:latest"
    echo "   docker pull langgenius/dify-web:latest"
    exit 1
fi

echo "📋 发现现有镜像:"
echo "$EXISTING_IMAGES"

# 应用 SSO 补丁
echo ""
echo "🔧 应用 SSO 补丁..."

if [ -f "../dify-keycloak.diff" ]; then
    echo "📋 应用补丁文件: ../dify-keycloak.diff"
    git apply ../dify-keycloak.diff
    echo "✅ 补丁应用完成"
else
    echo "⚠️  未找到补丁文件，使用脚本方式应用更改..."
    if [ -f "../scripts/apply-sso-integration.sh" ]; then
        bash ../scripts/apply-sso-integration.sh
    else
        echo "❌ 未找到 SSO 集成脚本"
        exit 1
    fi
fi

echo ""
echo "🐳 构建新镜像..."

# 构建 API 镜像
echo "🔨 构建 API 镜像..."
docker build -t dify-api-sso:latest -f docker/api/Dockerfile .

# 构建 Web 镜像
echo "🔨 构建 Web 镜像..."
docker build -t dify-web-sso:latest -f docker/web/Dockerfile .

echo ""
echo "💾 保存镜像到文件..."

# 创建输出目录
OUTPUT_DIR="../dify-sso-images-$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

# 保存镜像
echo "📦 保存 API 镜像..."
docker save dify-api-sso:latest -o "$OUTPUT_DIR/dify-api-sso.tar"

echo "📦 保存 Web 镜像..."
docker save dify-web-sso:latest -o "$OUTPUT_DIR/dify-web-sso.tar"

# 创建部署脚本
echo "📝 创建部署脚本..."
cat > "$OUTPUT_DIR/deploy.sh" << 'EOF'
#!/bin/bash

# Dify SSO 镜像部署脚本

set -e

echo "🚀 部署 Dify SSO 镜像..."

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

# 显示镜像信息
echo ""
echo "📋 已加载的镜像:"
docker images | grep dify-sso

echo ""
echo "🎉 部署完成！"
echo "📋 下一步："
echo "1. 更新 docker-compose.yaml 中的镜像名称"
echo "2. 添加必要的环境变量"
echo "3. 运行 'docker compose up -d' 启动服务"
EOF

chmod +x "$OUTPUT_DIR/deploy.sh"

# 创建环境变量配置示例
echo "📝 创建环境变量配置示例..."
cat > "$OUTPUT_DIR/env.example" << 'EOF'
# Dify SSO 环境变量配置示例

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

# 其他可选配置
ENABLE_SIGNUP=true
ENABLE_OAUTH_LOGIN=true
EOF

# 创建 docker-compose 示例
echo "📝 创建 docker-compose 示例..."
cat > "$OUTPUT_DIR/docker-compose.sso.yaml" << 'EOF'
version: '3.8'

services:
  api:
    image: dify-api-sso:latest
    container_name: dify-api-sso
    environment:
      # SSO 认证开关
      - ENABLE_SOCIAL_OAUTH_LOGIN=true
      
      # Keycloak 配置
      - KEYCLOAK_CLIENT_ID=dify-console
      - KEYCLOAK_CLIENT_SECRET=dify-console-secret
      - KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
      
      # Dify 服务地址
      - CONSOLE_API_URL=http://localhost:5001
      - CONSOLE_WEB_URL=http://localhost:3000
      
      # 用户权限
      - ALLOW_REGISTER=true
      - ALLOW_CREATE_WORKSPACE=true
      
      # 数据库配置（根据实际情况修改）
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USERNAME=postgres
      - DB_PASSWORD=password
      - DB_DATABASE=dify
      
      # Redis 配置（根据实际情况修改）
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=
      - REDIS_DB=0
    ports:
      - "5001:5001"
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  web:
    image: dify-web-sso:latest
    container_name: dify-web-sso
    environment:
      - CONSOLE_API_URL=http://localhost:5001
      - CONSOLE_WEB_URL=http://localhost:3000
    ports:
      - "3000:3000"
    depends_on:
      - api
    restart: unless-stopped

  postgres:
    image: postgres:15
    container_name: dify-postgres
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=dify
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: dify-redis
    ports:
      - "6379:6379"
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# 创建保持原有镜像名称的配置示例
echo "📝 创建保持原有镜像名称的配置示例..."
cat > "$OUTPUT_DIR/docker-compose.keep-image.yaml" << 'EOF'
version: '3.8'

services:
  api:
    # 保持原有镜像名称不变
    # image: langgenius/dify-api:latest
    container_name: dify-api
    environment:
      # 添加 SSO 环境变量
      - ENABLE_SOCIAL_OAUTH_LOGIN=true
      - KEYCLOAK_CLIENT_ID=dify-console
      - KEYCLOAK_CLIENT_SECRET=dify-console-secret
      - KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
      - CONSOLE_API_URL=http://localhost:5001
      - CONSOLE_WEB_URL=http://localhost:3000
      - ALLOW_REGISTER=true
      - ALLOW_CREATE_WORKSPACE=true
      
      # 保留原有的其他环境变量
      # - DB_HOST=postgres
      # - DB_PORT=5432
      # - DB_USERNAME=postgres
      # - DB_PASSWORD=password
      # - DB_DATABASE=dify
      # - REDIS_HOST=redis
      # - REDIS_PORT=6379
      # - REDIS_PASSWORD=
      # - REDIS_DB=0
    ports:
      - "5001:5001"
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  web:
    # 保持原有镜像名称不变
    # image: langgenius/dify-web:latest
    container_name: dify-web
    environment:
      - CONSOLE_API_URL=http://localhost:5001
      - CONSOLE_WEB_URL=http://localhost:3000
    ports:
      - "3000:3000"
    depends_on:
      - api
    restart: unless-stopped

  postgres:
    image: postgres:15
    container_name: dify-postgres
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=dify
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: dify-redis
    ports:
      - "6379:6379"
    restart: unless-stopped

volumes:
  postgres_data:
EOF

echo ""
echo "🎉 离线镜像构建完成！"
echo ""
echo "📁 输出目录: $OUTPUT_DIR"
echo "📦 包含文件:"
echo "  - dify-api-sso.tar (API 镜像)"
echo "  - dify-web-sso.tar (Web 镜像)"
echo "  - deploy.sh (部署脚本)"
echo "  - env.example (环境变量示例)"
echo "  - docker-compose.sso.yaml (使用新镜像名称的配置)"
echo "  - docker-compose.keep-image.yaml (保持原有镜像名称的配置)"
echo ""
echo "🚀 使用方法:"
echo ""
echo "方案 1: 使用新镜像名称（推荐）"
echo "1. 将整个 $OUTPUT_DIR 目录复制到目标服务器"
echo "2. 在目标服务器上运行: cd $OUTPUT_DIR && ./deploy.sh"
echo "3. 使用 docker-compose.sso.yaml 启动服务"
echo ""
echo "方案 2: 保持原有镜像名称"
echo "1. 将整个 $OUTPUT_DIR 目录复制到目标服务器"
echo "2. 在目标服务器上运行: cd $OUTPUT_DIR && ./deploy.sh"
echo "3. 使用 docker-compose.keep-image.yaml 启动服务"
echo "   (注意: 此方案需要确保原有镜像已包含 SSO 补丁)"
echo ""
echo "💡 提示: 此镜像包含了完整的 SSO 集成功能"

cd ..
