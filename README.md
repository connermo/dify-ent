# Dify Enterprise SSO (Local Keycloak)

This repo provides a dockerized Keycloak realm and a patch to enable Dify Console OAuth2 login via Keycloak.

## Usage

1. Start Keycloak:
   
2. Configure Dify (api env):
   - CONSOLE_API_URL=http://localhost:5001
   - CONSOLE_WEB_URL=http://localhost:3000
   - ENABLE_SOCIAL_OAUTH_LOGIN=true
   - KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
   - KEYCLOAK_CLIENT_ID=dify-console
   - KEYCLOAK_CLIENT_SECRET=dify-console-secret

3. Apply code edits in your Dify source (or use the patch below).

## Patch

Apply with:

