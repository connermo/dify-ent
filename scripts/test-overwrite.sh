#!/bin/bash

# 测试脚本：验证镜像覆盖功能

echo "=== 测试镜像覆盖功能 ==="

# 检查当前镜像
echo "当前 langgenius/dify-api 镜像:"
docker images | grep "langgenius/dify-api" || echo "未找到"

echo ""
echo "=== 测试构建脚本 ==="

# 测试帮助信息
echo "1. 测试帮助信息:"
./scripts/build-local-images.sh --help | grep -A 5 "Options:"

echo ""
echo "2. 测试确认提示 (按 N 取消):"
echo "langgenius/dify-api:latest" | ./scripts/build-local-images.sh api 2>&1 | head -20

echo ""
echo "3. 测试跳过确认 (--yes 选项):"
./scripts/build-local-images.sh --help | grep -A 10 "Options:" | grep "yes"

echo ""
echo "=== 测试完成 ==="
