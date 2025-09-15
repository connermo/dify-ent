# Dify 消息加密功能配置指南

## 功能概述

消息加密功能为 Dify 平台提供了对用户查询和AI回答的透明加密存储能力。当启用此功能时，所有新的消息内容都会在存储到数据库前进行加密，并在读取时自动解密。

## 配置选项

### 1. MESSAGE_ENCRYPTION_ENABLED

**作用**: 启用或禁用消息加密功能  
**类型**: 布尔值 (true/false)  
**默认值**: false  
**环境变量**: `MESSAGE_ENCRYPTION_ENABLED`

```bash
# 启用消息加密
MESSAGE_ENCRYPTION_ENABLED=true

# 禁用消息加密（默认）
MESSAGE_ENCRYPTION_ENABLED=false
```

### 2. ENCRYPTION_KEY_ID

**作用**: 指定用于消息加密的密钥ID  
**类型**: 字符串  
**默认值**: "dify_default_2025"  
**环境变量**: `ENCRYPTION_KEY_ID`

```bash
# 使用自定义密钥ID
ENCRYPTION_KEY_ID=my_custom_key_2025

# 使用默认密钥ID（可省略此配置）
ENCRYPTION_KEY_ID=dify_default_2025
```

## 配置方法

### 方法一：环境变量配置

在 `.env` 文件中添加配置：

```bash
# 启用消息加密功能
MESSAGE_ENCRYPTION_ENABLED=true

# 可选：指定自定义密钥ID
ENCRYPTION_KEY_ID=production_key_2025
```

### 方法二：配置文件配置

如果使用 TOML 配置文件 (`pyproject.toml`)，可以在相应部分添加：

```toml
[tool.dify.security]
MESSAGE_ENCRYPTION_ENABLED = true
ENCRYPTION_KEY_ID = "production_key_2025"
```

## 功能特性

### 1. 透明加密/解密

- **自动加密**: 当设置 `query` 或 `answer` 属性时，如果启用了加密功能，数据会自动加密
- **自动解密**: 当读取 `query` 或 `answer` 属性时，如果数据是加密的，会自动解密
- **向后兼容**: 现有的未加密数据仍然可以正常读取

### 2. 数据格式

- 加密的数据以 `ENC:` 前缀标识
- 数据库中的存储格式：`ENC:base64_encoded_encrypted_data`
- 应用程序读取时自动去除前缀并解密

### 3. 错误处理

- 如果解密失败，会尝试返回去掉 `ENC:` 前缀的原始数据
- 如果加密失败，会存储原始数据（不加密）
- 配置错误或密钥问题不会导致系统崩溃

## 安全考虑

### 1. 密钥管理

- `ENCRYPTION_KEY_ID` 应该是稳定的，一旦设置不建议频繁更改
- 建议使用描述性的密钥ID，便于密钥轮换时的管理
- 确保加密密钥本身的安全存储

### 2. 性能影响

- 加密/解密操作会带来一定的性能开销
- 建议在生产环境中进行性能测试
- 对于高并发场景，需要评估性能影响

### 3. 数据迁移

- 启用加密功能不会影响现有数据的读取
- 现有未加密数据会保持原样，新数据会被加密
- 如需对现有数据进行加密，需要单独的迁移脚本

## 使用示例

### 启用加密

```bash
# 在 .env 文件中
MESSAGE_ENCRYPTION_ENABLED=true
ENCRYPTION_KEY_ID=prod_2025
```

重启服务后，所有新的消息内容都会被加密存储。

### 禁用加密

```bash
# 在 .env 文件中
MESSAGE_ENCRYPTION_ENABLED=false
```

重启服务后，新的消息内容将以明文形式存储。现有的加密数据仍可正常读取。

## 故障排除

### 1. 解密失败

如果遇到解密失败的情况：
- 检查 `ENCRYPTION_KEY_ID` 配置是否正确
- 确认加密密钥是否可用
- 查看应用日志获取详细错误信息

### 2. 性能问题

如果遇到性能问题：
- 考虑是否真的需要加密所有消息
- 评估数据库和加密操作的性能开销
- 监控系统资源使用情况

### 3. 配置不生效

如果配置不生效：
- 确认服务已重启
- 检查环境变量是否正确设置
- 验证配置文件语法是否正确

## 建议

1. **测试环境先试用**: 在生产环境启用前，建议在测试环境充分测试
2. **备份数据**: 启用加密功能前，建议备份现有数据
3. **监控性能**: 启用后密切监控系统性能指标
4. **密钥管理**: 建立完善的密钥管理和轮换策略
