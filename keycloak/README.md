# NoMercy Keycloak Realm Configuration

## Overview

This directory contains the exported configuration for the `NoMercyTV` Keycloak realm.

- **Keycloak version**: 22.0.1
- **Realm name**: `NoMercyTV`
- **Production URL**: `https://auth.nomercy.tv`
- **Dev URL**: `https://auth-dev.nomercy.tv`
- **Realm internal ID**: `nomercy-ui`

The file `realm-export.json` is the source of truth for auth configuration. It was previously
only in the running Keycloak instance. If that instance is lost, this file is the recovery point.

## Secrets Policy

All secrets are stripped from `realm-export.json` and replaced with `REDACTED`. Do not commit
real secrets. The following fields are redacted:

- Client `secret` values (all clients)
- Identity provider `clientSecret` values (GitHub, GitLab, Google, Microsoft, Facebook, StackOverflow)
- SMTP server `password`
- Realm signing/encryption key material (`privateKey`, `secret` in KeyProvider components)
- reCAPTCHA `secret` in authenticator configs

When importing this file into a fresh Keycloak instance, you must replace all `REDACTED`
values with the real secrets from the password manager / 1Password vault before importing.

## Exporting a Fresh Copy

Run this from the production server. The `--users skip` flag prevents user PII from being
included in the export.

```bash
# SSH in
ssh root@134.209.137.208 -i ~/.ssh/digitalocean

# Run export inside the container (connects directly to Postgres, no admin token needed)
docker exec nomercy.tv-keycloak /opt/keycloak/bin/kc.sh export \
  --dir /tmp/realm-export \
  --realm NoMercyTV \
  --users skip \
  --db postgres \
  --db-url-host postgres-kc \
  --db-username keycloak \
  --db-password <KEYCLOAK_DATABASE_PASSWORD>

# Copy out
docker cp nomercy.tv-keycloak:/tmp/realm-export/NoMercyTV-realm.json /tmp/NoMercyTV-realm.json

# Transfer locally
exit
scp -i ~/.ssh/digitalocean root@134.209.137.208:/tmp/NoMercyTV-realm.json \
  ./infra/nomercy-stack/keycloak/realm-export-raw.json
```

Then scrub secrets before committing. The Python script used for scrubbing is documented at
the bottom of this README.

## Realm Settings

| Setting | Value |
|---|---|
| Registration allowed | Yes |
| Email as username | Yes |
| Verify email | Yes |
| Remember me | Yes |
| Brute force protection | Yes (permanent lockout after 30 failures) |
| SSL required | All |
| Default signature algorithm | RS256 |

### Token Lifetimes

| Token | Duration |
|---|---|
| Access token | 240 hours (10 days) |
| SSO session idle timeout | 30 days |
| SSO session max lifespan | 31 days |
| Offline session idle timeout | 7 days |
| Refresh token reuse | Disabled (single-use) |

Note: the 10-day access token lifetime is longer than typical. This is intentional for the
self-hosted media server use case — users should not be kicked out mid-stream.

## Clients

### Custom Clients

**nomercy-ui** — Primary client for all browser-facing flows.
- Public client (no secret required)
- Used by: nomercy-app-web (Vue), nomercy-app-android (Kotlin/AppAuth), InfiniFrame desktop
- Redirect URIs include deep link schemes: `nomercy://callback`, `nomercy://home`
- Custom scope: `client-roles-nomercy-ui`
- Auth flows: standard (PKCE), device flow (TV)

**nomercy-server** — Used by the .NET media server.
- Public client
- Used by: nomercy-media-server (.NET) for `client_credentials` grant → service account token,
  and for the browser-based setup/onboarding PKCE flow (callback paths `/sso-callback` and
  `/setup/silent-sso`, built client-side from `window.location` in `setup.js` — see
  `NoMercy.Setup.Resources.setup.js` and `NoMercy.Setup.Server.SetupEndpoints`)
- Redirect URIs: `https://*` and `http://*`

  Every self-hosted server has a unique redirect host —
  `{ip-dashed}.{device-id}.srv.nomercy.tv:{port}` (synthesized DNS) or the legacy
  `{ip-dashed}.{device-id}.nomercy.tv:{port}` apex form, plus a raw LAN address and
  `localhost` during first boot. **Keycloak only treats `*` as a wildcard when it is the
  final character of the registered URI** (prefix match on everything before it); a `*`
  placed mid-string (e.g. in `https://*.nomercy.tv:*/sso-callback/*`) is matched
  *literally* and will never match a real hostname/port. Because the variable part of
  our redirect host (the device-id) is a *prefix*, not a suffix, there is no
  Keycloak-native pattern that pins the domain suffix or the callback path while
  leaving the host open — the only working wildcard is scheme-level. Do not "tighten"
  this back to a subdomain/port wildcard; it silently stops matching every fresh
  server and reproduces the onboarding "Invalid parameter: redirect_uri" failure.
  PKCE (no client secret, code alone is unusable without the verifier) is the actual
  mitigation for the open-redirect surface this leaves; `nomercy-ui` already runs an
  even more permissive bare `*` (any scheme) for its native-app deep-link redirects.

**nomercy-api** — Service account client for nomercy-tv (Laravel backend).
- Confidential client (has secret — stored in Laravel `.env`)
- Service accounts enabled — used for token exchange (RFC 8693)
- This is how nomercy-tv impersonates users to generate tokens for media servers
- Used by: nomercy-tv `Server::apiToken()` flow

**https://gitlab.nomercy.tv** — GitLab instance OAuth client.
- Confidential client
- Redirect URI: `https://gitlab.nomercy.tv/*`

**admin-cli** — Keycloak admin CLI client.
- Public client
- Used for administrative operations and the export command

### Built-In Clients

`account`, `account-console`, `broker`, `realm-management`, `security-admin-console` — standard
Keycloak built-in clients, not customized.

## Identity Providers (Social Login)

| Provider | Alias | Status | Notes |
|---|---|---|---|
| GitHub | `github` | Enabled | Primary social login, shown on login page |
| Google | `google` | Enabled | Primary social login, shown on login page, FORCE sync mode |
| GitLab | `gitlab` | Enabled | Hidden from login page (link-only in practice) |
| Microsoft | `oidc` | Enabled | Hidden from login page, Azure AD tenant configured |
| Facebook | `facebook` | Enabled | Link-only (`linkOnly: true`), shown on login page |
| StackOverflow | `stackoverflow` | Enabled | Hidden from login page |

GitHub and Google are the active primary social logins. Facebook is link-only (cannot be used
as a primary login). Microsoft and StackOverflow are hidden (available but not promoted).

Microsoft is configured against a specific Azure AD tenant
(`d7a5d865-3517-4a0d-a192-6498208f520e`).

## Realm Roles

| Role | Description |
|---|---|
| `impersonatable` | User can be impersonated by admins |
| `nova` | Access to Nova (Laravel Nova admin panel) |
| `offline_access` | Default role — grants offline access token |
| `uma_authorization` | Default role — UMA authorization |
| `passwordless` | User has chosen passkey-only login |
| `disable password login` | Password login disabled for this user |
| `default-roles-nomercytv` | Composite: offline_access + impersonatable + uma_authorization |

## Client Roles (nomercy-api)

These are the permission roles validated by the Laravel Gate in nomercy-tv and by the
`CheckKeycloak` middleware.

**Composite roles (assigned to users):**
- `super-admin` — full system access
- `admin` — administrative access
- `infra-admin` — infrastructure management
- `support-agent` — read-only support access
- `content-manager` — content management
- `api server` — media server service account role
- `user` — base authenticated user

**Granular permissions:**
| Permission | Description |
|---|---|
| `admin:users:read/create/update/delete/restore` | User management |
| `admin:users:impersonate` | User impersonation |
| `admin:servers:read/update/delete/restore` | Server management |
| `admin:blog:read/create/update/delete/restore` | Blog content |
| `admin:dns:read/create/delete` | DNS records |
| `admin:jobs:read/update/delete` | Background jobs |
| `admin:notifications:read/create` | Notifications |
| `admin:invites:read/create/delete` | Invite codes |
| `admin:messages:read/create` | Direct messages |
| `admin:certificates:update` | SSL certificates |
| `admin:tunnels:create/delete` | Cloudflare tunnels |
| `admin:keycloak:read/update` | Keycloak admin |
| `admin:activity:read` | Activity log |
| `admin:dashboard:read` | Dashboard access |
| `infra:dns:read/create` | Infrastructure DNS |
| `infra:tunnels:read/create` | Infrastructure tunnels |
| `infra:custom-domain:read/create` | Custom domains |
| `super:force-delete:all/users/servers/posts` | Permanent deletion |

## Custom Authentication Flows

The realm has several custom flows beyond the Keycloak defaults:

**Session-NoPW-Passkey-OTP-Password** — The main browser login flow. Supports:
1. Passkey (WebAuthn) — for users with `disable password login` role
2. OTP — time-based one-time passwords
3. Password fallback — for users who haven't set up a passkey

**No Password** — Conditional sub-flow: only runs if the user does NOT have the
`passwordless` role.

**Password Fallback** — Conditional sub-flow: runs if the user doesn't complete passkey auth.

**2FA / OTP flows** — Separate flows for OTP registration and validation.

**Passkey flows** — WebAuthn registration (including passwordless WebAuthn).

## Custom Scopes

Beyond Keycloak defaults (`profile`, `email`, `roles`, `offline_access`, etc.):

**client-roles-nomercy-ui** — Maps `nomercy-ui` realm roles into the token. Used by the
frontend to gate access to dashboard features (e.g., `moderator` role check).

## Email / SMTP

Provider: Strato (`smtp.strato.com:465`)
From address: `noreply@nomercy.tv`
Display name: `NoMercy Entertainment`
Auth: enabled, SSL: enabled

Login theme: `NoMercy` (custom theme in `./themes/`)
Account theme: `keycloak.v3`
Admin theme: `keycloak.v2`
Email theme: `keycloak` (default)

## Keycloak Features Enabled

```
token-exchange, preview, admin2, docker
```

- `token-exchange` — required for nomercy-tv's `Server::apiToken()` flow (RFC 8693)
- `preview` — enables preview features including `declarative-user-profile`
- `admin2` — new admin UI
- `docker` — Docker registry auth support

## Recovery / Import Procedure

If the Keycloak instance is lost:

1. Start a fresh Keycloak 22.0.1 instance
2. Copy `realm-export.json` and replace all `REDACTED` values with real secrets from vault
3. Import via Admin UI: Realm Settings > Import realm, or via CLI:
   ```bash
   /opt/keycloak/bin/kc.sh import --file /path/to/NoMercyTV-realm.json
   ```
4. Verify all clients have their correct secrets configured
5. Verify identity providers can perform OAuth handshake
6. Update any `.env` files that reference `KEYCLOAK_CLIENT_SECRET` or similar
7. Rotate the JWKS cache in nomercy-tv if the RSA key changed (restart container)

After import, the RSA key pair will be regenerated. This means the public key in `nomercy-tv`'s
`.env` (`KEYCLOAK_REALM_PUBLIC_KEY`) must be updated to match the new key from:
`https://auth.nomercy.tv/realms/NoMercyTV/protocol/openid-connect/certs`

## Secrets Scrubbing Script

```python
import json

with open('realm-export-raw.json') as f:
    realm = json.load(f)

# Client secrets
for c in realm.get('clients', []):
    if 'secret' in c:
        c['secret'] = 'REDACTED'

# Identity provider secrets
for idp in realm.get('identityProviders', []):
    cfg = idp.get('config', {})
    if 'clientSecret' in cfg:
        cfg['clientSecret'] = 'REDACTED'
    if 'key' in cfg:  # StackOverflow API key
        cfg['key'] = 'REDACTED'

# SMTP password
if 'smtpServer' in realm and 'password' in realm['smtpServer']:
    realm['smtpServer']['password'] = 'REDACTED'

# Realm signing/encryption key material
for kp in realm.get('components', {}).get('org.keycloak.keys.KeyProvider', []):
    cfg = kp.get('config', {})
    if 'secret' in cfg:
        cfg['secret'] = ['REDACTED']
    if 'privateKey' in cfg:
        cfg['privateKey'] = ['REDACTED']

# reCAPTCHA secrets in authenticatorConfig
for ac in realm.get('authenticatorConfig', []):
    cfg = ac.get('config', {})
    if 'secret' in cfg:
        cfg['secret'] = 'REDACTED'

with open('realm-export.json', 'w') as f:
    json.dump(realm, f, indent=2)
```
