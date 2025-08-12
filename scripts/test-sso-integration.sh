#!/bin/bash

# Test SSO Integration
# This script verifies that the SSO integration is correctly applied

set -e

echo "🧪 Testing SSO Integration..."

# Check if we're in the right directory
if [ ! -d "dify/api" ]; then
    echo "❌ Error: dify/api directory not found. Please run this script from the project root."
    exit 1
fi

cd dify

echo "🔍 Checking Keycloak configuration..."
if grep -q "KEYCLOAK_CLIENT_ID" api/configs/feature/__init__.py; then
    echo "✅ Keycloak configuration found"
else
    echo "❌ Keycloak configuration missing"
    exit 1
fi

echo "🔍 Checking KeycloakOAuth class..."
if grep -q "class KeycloakOAuth" api/libs/oauth.py; then
    echo "✅ KeycloakOAuth class found"
else
    echo "❌ KeycloakOAuth class missing"
    exit 1
fi

echo "🔍 Checking OAuth controller updates..."
if grep -q "KeycloakOAuth" api/controllers/console/auth/oauth.py; then
    echo "✅ OAuth controller updated with Keycloak support"
else
    echo "❌ OAuth controller not updated"
    exit 1
fi

echo "🔍 Checking OAuth providers API..."
if grep -q "OAuthProvidersApi" api/controllers/console/auth/oauth.py; then
    echo "✅ OAuth providers API found"
else
    echo "❌ OAuth providers API missing"
    exit 1
fi

echo "🔍 Checking docker-compose.yaml..."
if grep -q "KEYCLOAK_CLIENT_ID" docker/docker-compose.yaml; then
    echo "✅ Docker-compose updated with SSO variables"
else
    echo "❌ Docker-compose missing SSO variables"
    exit 1
fi

echo "🔍 Checking .env file..."
if [ -f ".env" ] && grep -q "KEYCLOAK_CLIENT_ID" .env; then
    echo "✅ .env file configured for SSO"
else
    echo "❌ .env file missing or not configured"
    exit 1
fi

cd ..

echo ""
echo "🎉 All SSO Integration Tests Passed!"
echo ""
echo "📋 Verified components:"
echo "  ✅ Keycloak configuration fields in api/configs/feature/__init__.py"
echo "  ✅ KeycloakOAuth class in api/libs/oauth.py"
echo "  ✅ OAuth controller updates in api/controllers/console/auth/oauth.py"
echo "  ✅ OAuth providers API endpoint"
echo "  ✅ Docker-compose SSO environment variables"
echo "  ✅ Environment configuration file"
echo ""
echo "🚀 Ready for deployment!"