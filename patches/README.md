# Dify 补丁说明

## 消息加密功能补丁

### 可用补丁文件

1. **`dify-encryption-complete.patch`** - 完整的消息加密功能补丁
   - 包含配置系统和模型修改
   - 推荐使用这个补丁

2. **`dify-encryption-config-only.patch`** - 仅配置文件修改
   - 只包含 `api/configs/feature/__init__.py` 的修改

3. **`dify-encryption-model-only.patch`** - 仅模型文件修改
   - 只包含 `api/models/model.py` 的修改

### 使用方法

```bash
# 进入 dify 目录
cd dify

# 应用完整补丁
git apply ../patches/dify-encryption-complete.patch

# 或者分别应用
git apply ../patches/dify-encryption-config-only.patch
git apply ../patches/dify-encryption-model-only.patch
```

### 功能配置

在 `.env` 文件中添加：

```bash
# 启用消息加密
MESSAGE_ENCRYPTION_ENABLED=true

# 可选：自定义加密密钥ID
ENCRYPTION_KEY_ID=my_production_key_2025
```

### 验证应用

```bash
# 检查配置文件修改
grep -n "MESSAGE_ENCRYPTION_ENABLED" api/configs/feature/__init__.py

# 检查模型文件修改
grep -n "_query.*mapped_column" api/models/model.py
grep -n "def _is_encryption_enabled" api/models/model.py
```

## 其他补丁

- **`clear-logs-final-clean.patch`** - 日志清理功能补丁
- **`clear-logs-selective.patch`** - 选择性日志清理补丁
