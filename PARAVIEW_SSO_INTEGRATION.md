# Paraview SSO OAuth2.0 集成指南

本文档详细说明如何在Dify中集成[Paraview Software的Single Sign-On产品](https://www.paraviewsoft.com/products/single-sign-on)。

## 🎯 集成概述

Paraview SSO是一个企业级的身份和访问管理(IAM)解决方案，支持标准的OAuth2.0/OpenID Connect协议。通过本集成，用户可以使用Paraview SSO账户登录Dify。

## 📋 前提条件

1. **Paraview SSO服务器**: 确保你有一个运行中的Paraview SSO实例
2. **OAuth2.0客户端配置**: 在Paraview SSO中创建一个OAuth2.0应用程序
3. **Dify管理员权限**: 能够修改Dify的环境配置

## 🔧 Paraview SSO 配置

### 1. 在Paraview SSO中创建OAuth应用

登录到你的Paraview SSO管理界面，创建新的OAuth2.0应用程序：

```
应用名称: Dify Console
应用类型: Web Application
授权类型: Authorization Code
客户端认证: Client Secret (Post)
重定向URI: http://your-dify-domain.com/console/api/oauth/authorize/paraview
作用域: openid profile email
```

记录下以下信息：
- **Client ID**: 应用程序的客户端ID
- **Client Secret**: 应用程序的客户端密钥  
- **SSO Base URL**: Paraview SSO的基础URL (例如: https://your-paraview-sso.com)

### 2. 确认API端点

确保你的Paraview SSO支持以下标准端点：
- 授权端点: `{SSO_URL}/authorize`
- 令牌端点: `{SSO_URL}/accessToken`
- 用户信息端点: `{SSO_URL}/profile`

> **注意**: 如果你的Paraview SSO使用不同的端点路径，请在`ParaviewOAuth`类中相应调整`_AUTH_URL`、`_TOKEN_URL`和`_USER_INFO_URL`。

## 🚀 Dify 配置

### 1. 环境变量配置

在你的Dify环境中添加以下环境变量：

```bash
# 启用社交OAuth登录
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Paraview SSO配置
PARAVIEW_CLIENT_ID=your_paraview_client_id
PARAVIEW_CLIENT_SECRET=your_paraview_client_secret
PARAVIEW_SSO_URL=https://your-paraview-sso.com

# Dify服务地址配置
CONSOLE_API_URL=http://your-dify-domain.com
CONSOLE_WEB_URL=http://your-dify-domain.com
```

### 2. Docker Compose 配置

如果使用Docker Compose部署，确保在`docker-compose.yaml`中包含这些环境变量：

```yaml
services:
  api:
    environment:
      - ENABLE_SOCIAL_OAUTH_LOGIN=${ENABLE_SOCIAL_OAUTH_LOGIN:-false}
      - PARAVIEW_CLIENT_ID=${PARAVIEW_CLIENT_ID:-}
      - PARAVIEW_CLIENT_SECRET=${PARAVIEW_CLIENT_SECRET:-}
      - PARAVIEW_SSO_URL=${PARAVIEW_SSO_URL:-}
      - CONSOLE_API_URL=${CONSOLE_API_URL}
      - CONSOLE_WEB_URL=${CONSOLE_WEB_URL}
  
  web:
    environment:
      - CONSOLE_API_URL=${CONSOLE_API_URL}
```

### 3. 重启服务

配置完成后，重启Dify服务：

```bash
# 如果使用Docker Compose
docker-compose restart api web

# 如果使用Kubernetes
kubectl rollout restart deployment/dify-api
kubectl rollout restart deployment/dify-web
```

## 🔍 验证集成

### 1. 检查OAuth提供商

访问API端点检查Paraview是否正确注册：

```bash
curl http://your-dify-domain.com/console/api/oauth/providers
```

预期响应应包含：
```json
{
  "providers": {
    "github": false,
    "google": false,
    "keycloak": false,
    "paraview": true
  }
}
```

### 2. 测试登录流程

1. 访问Dify登录页面: `http://your-dify-domain.com/signin`
2. 应该看到"Continue with Paraview SSO"按钮
3. 点击按钮应该重定向到Paraview SSO登录页面
4. 登录后应该重定向回Dify并自动创建/登录账户

## 🛠️ 故障排除

### 常见问题

#### 1. "Invalid provider" 错误
**原因**: OAuth提供商配置不正确
**解决方案**: 
- 检查环境变量是否正确设置
- 确保所有必需的配置项都有值
- 重启API服务

#### 2. "OAuth process failed" 错误
**原因**: 与Paraview SSO通信失败
**解决方案**:
- 检查`PARAVIEW_SSO_URL`是否正确且可访问
- 验证Client ID和Client Secret是否正确
- 检查网络连接和防火墙设置

#### 3. 重定向URI不匹配
**原因**: Paraview SSO中配置的重定向URI与实际不符
**解决方案**:
- 确保Paraview SSO中的重定向URI为: `{CONSOLE_API_URL}/console/api/oauth/authorize/paraview`
- 检查`CONSOLE_API_URL`环境变量是否正确

#### 4. 用户信息获取失败
**原因**: 用户信息端点响应格式不匹配
**解决方案**:
- 检查Paraview SSO的用户信息端点响应格式
- 如果格式不同，修改`ParaviewOAuth._transform_user_info`方法中的字段映射

### 调试步骤

1. **启用调试日志**:
   ```bash
   export LOG_LEVEL=DEBUG
   ```

2. **检查API日志**:
   ```bash
   docker-compose logs -f api
   ```

3. **测试API端点**:
   ```bash
   # 测试授权URL生成
   curl "http://your-dify-domain.com/console/api/oauth/login/paraview"
   
   # 测试提供商列表
   curl "http://your-dify-domain.com/console/api/oauth/providers"
   ```

## 🔐 安全考虑

1. **HTTPS使用**: 生产环境中务必使用HTTPS
2. **客户端密钥保护**: 确保`PARAVIEW_CLIENT_SECRET`安全存储
3. **作用域限制**: 仅请求必需的OAuth作用域
4. **会话管理**: 定期检查和清理过期的OAuth会话

## 📝 API端点说明

| 端点 | 方法 | 描述 |
|------|------|------|
| `/console/api/oauth/providers` | GET | 获取可用的OAuth提供商列表 |
| `/console/api/oauth/login/paraview` | GET | 启动Paraview SSO登录流程 |
| `/console/api/oauth/authorize/paraview` | GET | Paraview SSO回调端点 |

## 🔄 更新和维护

### 更新Paraview SSO配置

如果需要更新Paraview SSO配置：

1. 更新环境变量
2. 重启API服务
3. 验证新配置是否生效

### 迁移到新的Paraview SSO实例

1. 在新实例中创建OAuth应用程序
2. 更新`PARAVIEW_SSO_URL`、`PARAVIEW_CLIENT_ID`和`PARAVIEW_CLIENT_SECRET`
3. 重启服务
4. 通知用户可能需要重新授权

## 📞 技术支持

如果遇到问题：

1. 首先检查本文档的故障排除部分
2. 查看Dify和Paraview SSO的日志
3. 验证网络连接和配置
4. 联系Paraview Software技术支持(如果是Paraview SSO相关问题)

## 🎉 总结

通过本集成，你已经成功将Paraview SSO OAuth2.0认证添加到Dify中。用户现在可以使用他们的Paraview SSO账户登录Dify，享受单点登录的便利。

集成特性：
- ✅ 标准OAuth2.0/OpenID Connect支持
- ✅ 用户信息自动映射
- ✅ 多语言界面支持
- ✅ 完整的错误处理
- ✅ 企业级安全标准
- ✅ 简洁的配置方式
