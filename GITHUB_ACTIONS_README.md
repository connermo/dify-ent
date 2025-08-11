# GitHub Actions for Dify Enterprise SSO

这个仓库包含了自动同步上游Dify仓库并构建Docker镜像的GitHub Actions工作流。

## 🚀 功能特性

- **自动同步**: 每天自动从上游仓库 `langgenius/dify` 同步最新代码
- **补丁应用**: 自动应用Keycloak OAuth集成补丁
- **多平台构建**: 支持 `linux/amd64` 和 `linux/arm64` 架构
- **Docker镜像**: 自动构建并推送API、Web和Worker镜像
- **版本管理**: 自动创建GitHub Release和标签
- **环境变量**: 自动更新docker-compose.yaml中的Keycloak配置

## 📋 工作流文件

### 主要工作流: `sync-dify.yml`

这个工作流负责：
1. 检查上游仓库更新
2. 同步最新代码
3. 应用Keycloak补丁
4. 构建Docker镜像
5. 推送镜像到容器仓库
6. 创建Release和标签

## ⚙️ 配置说明

### 环境变量

工作流使用以下环境变量：

```yaml
env:
  UPSTREAM_REPO: langgenius/dify          # 上游仓库
  UPSTREAM_BRANCH: main                   # 上游分支
  DOCKER_REGISTRY: ghcr.io                # Docker镜像仓库
  IMAGE_NAME: ${{ github.repository }}/dify  # 镜像名称前缀
  DOCKER_PLATFORMS: linux/amd64,linux/arm64  # 支持的平台
```

### 触发条件

工作流在以下情况下触发：

1. **定时触发**: 每天凌晨2点UTC (`cron: '0 2 * * *'`)
2. **手动触发**: 通过GitHub Actions页面手动运行
3. **推送触发**: 当相关文件更改时自动运行

### 手动触发选项

手动触发时可以选择：
- `force_sync`: 强制同步，即使没有更新也执行完整流程

## 🔧 使用方法

### 1. 启用工作流

1. 将 `.github/workflows/sync-dify.yml` 文件添加到你的仓库
2. 确保仓库有适当的权限设置
3. 工作流将自动开始运行

### 2. 手动运行

1. 进入仓库的 "Actions" 标签页
2. 选择 "Sync Dify from Upstream and Build Images" 工作流
3. 点击 "Run workflow"
4. 选择分支和选项（如强制同步）
5. 点击 "Run workflow"

### 3. 查看结果

工作流完成后，你可以：
- 查看构建的Docker镜像
- 检查GitHub Release
- 查看同步的代码更改
- 下载构建的镜像

## 📦 Docker镜像

工作流会构建以下镜像：

- **API镜像**: `ghcr.io/{username}/dify-api:latest`
- **Web镜像**: `ghcr.io/{username}/dify-web:latest`
- **Worker镜像**: `ghcr.io/{username}/dify-worker:latest`

每个镜像都有多个标签：
- `latest`: 最新版本
- `{commit-sha}`: 基于Git提交的版本
- `v{date}`: 基于日期的版本

## 🔐 权限要求

确保仓库有以下权限：

1. **Actions**: 允许运行GitHub Actions
2. **Contents**: 允许读写仓库内容
3. **Packages**: 允许推送Docker镜像
4. **Releases**: 允许创建Release和标签

## 📝 自定义配置

### 修改上游仓库

编辑 `.github/workflows/sync-dify.yml` 中的环境变量：

```yaml
env:
  UPSTREAM_REPO: your-username/your-repo
  UPSTREAM_BRANCH: main
```

### 修改Docker仓库

```yaml
env:
  DOCKER_REGISTRY: docker.io
  IMAGE_NAME: your-username/dify
```

### 修改构建平台

```yaml
env:
  DOCKER_PLATFORMS: linux/amd64,linux/arm64,linux/arm/v7
```

### 修改同步频率

```yaml
on:
  schedule:
    - cron: '0 */6 * * *'  # 每6小时运行一次
```

## 🚨 故障排除

### 常见问题

1. **补丁应用失败**
   - 检查补丁文件是否与上游代码兼容
   - 手动应用补丁并解决冲突
   - 更新补丁文件

2. **Docker构建失败**
   - 检查Dockerfile是否存在
   - 验证构建上下文路径
   - 检查网络连接和权限

3. **权限错误**
   - 确保仓库有适当的权限设置
   - 检查GitHub Token是否有效
   - 验证容器仓库访问权限

### 调试步骤

1. 查看工作流日志
2. 检查各个步骤的输出
3. 验证文件路径和权限
4. 测试手动命令

## 📚 相关资源

- [GitHub Actions文档](https://docs.github.com/en/actions)
- [Docker Buildx文档](https://docs.docker.com/buildx/)
- [Dify官方仓库](https://github.com/langgenius/dify)
- [Keycloak文档](https://www.keycloak.org/documentation)

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个工作流！

## 📄 许可证

本项目采用MIT许可证 - 详见LICENSE文件。
