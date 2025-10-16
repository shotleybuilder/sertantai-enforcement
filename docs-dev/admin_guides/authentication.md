# Admin Authentication Guide

Complete guide to admin authentication and access control in the EHS Enforcement system.

## Table of Contents

- [Overview](#overview)
- [How Authentication Works](#how-authentication-works)
- [Admin Access Configuration](#admin-access-configuration)
- [Logging In](#logging-in)
- [Managing Admin Users](#managing-admin-users)
- [Checking Your Access](#checking-your-access)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Overview

The EHS Enforcement system uses **GitHub OAuth** for authentication with a configurable allowlist of admin users. Only authorized GitHub users can access the admin interface.

**Key Concepts:**
- **Authentication**: Verifying identity via GitHub OAuth
- **Authorization**: Checking if authenticated user is in the allowlist
- **Admin Access**: Controlled by `GITHUB_ALLOWED_USERS` environment variable

---

## How Authentication Works

### Authentication Flow

1. **User visits admin area** (e.g., `/admin/scraping`)
2. **System checks authentication**:
   - Not logged in? → Redirect to GitHub OAuth
   - Logged in? → Continue to step 3
3. **System checks authorization**:
   - GitHub username in `GITHUB_ALLOWED_USERS`? → Grant admin access
   - Not in allowlist? → Show "Access Denied" message
4. **User accesses admin interface**

### Technology Stack

- **OAuth Provider**: GitHub
- **Framework**: Phoenix LiveView with Ash Authentication
- **Session Management**: Phoenix sessions (cookie-based)
- **Authorization Check**: `lib/ehs_enforcement_web/plugs/auth_helpers.ex`

---

## Admin Access Configuration

### Current Admin Users

**Default Admin**: `shotleybuilder`

This is configured via the `GITHUB_ALLOWED_USERS` environment variable.

### Configuration Files

**Development** (`.env.test`):
```bash
GITHUB_ALLOWED_USERS=shotleybuilder
```

**Production** (on sertantai server):
```bash
# In ~/infrastructure/docker/.env
GITHUB_ALLOWED_USERS=shotleybuilder,other_admin
```

### Environment Variables

All authentication-related environment variables:

```bash
# GitHub OAuth Application
GITHUB_CLIENT_ID=your_github_oauth_app_client_id
GITHUB_CLIENT_SECRET=your_github_oauth_app_secret

# Admin Access Control
GITHUB_ALLOWED_USERS=shotleybuilder,user2,user3  # Comma-separated list

# Optional: GitHub Repository Access (for additional checks)
GITHUB_REPO_OWNER=owner_name
GITHUB_REPO_NAME=repo_name
GITHUB_ACCESS_TOKEN=github_personal_access_token

# Redirect URI
GITHUB_REDIRECT_URI=http://localhost:4002/auth/user/github/callback
```

---

## Logging In

### Development Environment

1. **Start the application**:
   ```bash
   ./scripts/development/ehs-dev.sh
   # Or
   mix phx.server
   ```

2. **Visit the admin area**:
   ```
   http://localhost:4002/admin
   ```

3. **Click "Sign in with GitHub"**

4. **Authorize the application** (first time only):
   - GitHub will ask you to authorize the OAuth app
   - Click "Authorize" to grant access

5. **Access granted**:
   - You'll be redirected back to the admin interface
   - Your session persists across visits

### Production Environment

1. **Visit production URL**:
   ```
   https://legal.sertantai.com/admin
   ```

2. **Follow same OAuth flow** as development

3. **Note**: Production uses different OAuth app credentials

---

## Managing Admin Users

### Adding Admin Users

**Development**:

1. Edit `.env.test` or your local `.env`:
   ```bash
   GITHUB_ALLOWED_USERS=shotleybuilder,new_user,another_user
   ```

2. Restart the application:
   ```bash
   mix phx.server
   ```

**Production**:

1. SSH to production server:
   ```bash
   ssh sertantai
   ```

2. Edit environment file:
   ```bash
   cd ~/infrastructure/docker
   nano .env
   ```

3. Add user to `GITHUB_ALLOWED_USERS`:
   ```bash
   GITHUB_ALLOWED_USERS=shotleybuilder,new_admin_user
   ```

4. Restart the application:
   ```bash
   docker compose restart ehs-enforcement
   ```

### Removing Admin Users

Same process as adding, but remove the username from the comma-separated list:

```bash
# Before
GITHUB_ALLOWED_USERS=shotleybuilder,temp_user,other_admin

# After (removed temp_user)
GITHUB_ALLOWED_USERS=shotleybuilder,other_admin
```

**Important**: Always restart the application after changes!

### User List Format

```bash
# ✅ Correct formats
GITHUB_ALLOWED_USERS=user1
GITHUB_ALLOWED_USERS=user1,user2
GITHUB_ALLOWED_USERS=user1,user2,user3

# ❌ Incorrect formats
GITHUB_ALLOWED_USERS=user1, user2          # Spaces (will be trimmed, but avoid)
GITHUB_ALLOWED_USERS="user1,user2"         # Quotes (may cause issues)
GITHUB_ALLOWED_USERS=user1 user2           # No comma separator
```

---

## Checking Your Access

### Check Current Admin Users

**Development**:
```bash
# Check environment variable
echo $GITHUB_ALLOWED_USERS

# Or check .env.test
cat .env.test | grep GITHUB_ALLOWED_USERS
```

**Production**:
```bash
# SSH to server
ssh sertantai

# Check environment
cd ~/infrastructure/docker
grep GITHUB_ALLOWED_USERS .env
```

### Verify Your GitHub Username

1. **Visit GitHub**: https://github.com
2. **Check your profile URL**: `https://github.com/YOUR_USERNAME`
3. **Your username** is the part after `github.com/`

Example:
- URL: `https://github.com/shotleybuilder`
- Username: `shotleybuilder`

### Test Authentication

**In IEx console**:
```elixir
# Start IEx
iex -S mix phx.server

# Check configuration
config = Application.get_env(:ehs_enforcement, :github_admin)
config[:allowed_users]
# Should return: ["shotleybuilder"] or list of users

# Check if specific user is allowed
"shotleybuilder" in config[:allowed_users]
# Should return: true
```

---

## Troubleshooting

### Cannot Access Admin Interface

**Symptom**: "Access Denied" or redirect to login

**Solutions**:

1. **Check if you're logged in**:
   - Look for user icon/name in top navigation
   - If not, click "Sign in with GitHub"

2. **Verify your GitHub username is in allowlist**:
   ```bash
   # Check environment variable
   echo $GITHUB_ALLOWED_USERS

   # Should include your username
   ```

3. **Check for typos in username**:
   - GitHub usernames are case-sensitive
   - No spaces or special characters

4. **Restart application** after environment changes:
   ```bash
   # Development
   mix phx.server

   # Production
   ssh sertantai
   cd ~/infrastructure/docker
   docker compose restart ehs-enforcement
   ```

---

### OAuth Callback Errors

**Symptom**: Error after GitHub authorization

**Solutions**:

1. **Check redirect URI matches**:
   ```bash
   # Development
   GITHUB_REDIRECT_URI=http://localhost:4002/auth/user/github/callback

   # Production
   GITHUB_REDIRECT_URI=https://legal.sertantai.com/auth/user/github/callback
   ```

2. **Verify OAuth app configuration**:
   - Go to GitHub Settings → Developer settings → OAuth Apps
   - Check "Authorization callback URL" matches `GITHUB_REDIRECT_URI`

3. **Check client credentials**:
   ```bash
   # Ensure these are set
   echo $GITHUB_CLIENT_ID
   echo $GITHUB_CLIENT_SECRET
   ```

---

### Session Expired

**Symptom**: Logged out after period of inactivity

**Solution**: Simply log in again via GitHub OAuth

**Note**: Sessions expire after 24 hours by default (configurable in `config/config.exs`)

---

### GitHub OAuth App Not Found

**Symptom**: OAuth error, invalid client ID

**Solutions**:

1. **Verify OAuth app exists**:
   - Go to https://github.com/settings/developers
   - Check "OAuth Apps" section
   - Ensure app is created for this project

2. **Create new OAuth app** if needed:
   - Application name: "EHS Enforcement (Dev)" or "EHS Enforcement (Production)"
   - Homepage URL: `http://localhost:4002` or production URL
   - Authorization callback URL: Match your `GITHUB_REDIRECT_URI`
   - Copy Client ID and generate new Client Secret
   - Update environment variables

---

## Security Best Practices

### Environment Variable Management

✅ **Do**:
- Use `.env` files (never commit to git)
- Use different OAuth apps for dev/prod
- Rotate secrets periodically
- Keep client secrets secure

❌ **Don't**:
- Commit secrets to version control
- Share OAuth app credentials
- Use production secrets in development
- Leave default/example values in production

### Admin User Management

✅ **Do**:
- Maintain minimal admin user list
- Review admin access quarterly
- Remove access for departed team members
- Use organization GitHub accounts when possible

❌ **Don't**:
- Add temporary/test users to production
- Share admin credentials
- Grant admin access unnecessarily
- Use personal accounts for automated systems

### Session Security

✅ **Do**:
- Use HTTPS in production (enforced)
- Configure appropriate session timeout
- Monitor for suspicious login patterns
- Log admin actions

❌ **Don't**:
- Disable CSRF protection
- Use HTTP in production
- Share session cookies
- Stay logged in on shared computers

---

## Configuration Reference

### config/runtime.exs

The authentication configuration is defined here:

```elixir
# Development
config :ehs_enforcement, :github_admin,
  owner: System.get_env("GITHUB_REPO_OWNER"),
  repo: System.get_env("GITHUB_REPO_NAME"),
  access_token: System.get_env("GITHUB_ACCESS_TOKEN"),
  allowed_users: System.get_env("GITHUB_ALLOWED_USERS", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
```

### Authorization Check Location

`lib/ehs_enforcement_web/plugs/auth_helpers.ex:74`:
```elixir
defp check_github_repository_permissions(user) do
  config = Application.get_env(:ehs_enforcement, :github_admin, %{})
  allowed_users = config[:allowed_users] || []

  user.github_login in allowed_users
end
```

---

## Quick Reference

### Essential Commands

```bash
# Check current admin users
echo $GITHUB_ALLOWED_USERS

# Add admin user (development)
# Edit .env.test, then:
mix phx.server

# Add admin user (production)
ssh sertantai
cd ~/infrastructure/docker
nano .env  # Edit GITHUB_ALLOWED_USERS
docker compose restart ehs-enforcement

# Test authentication in IEx
iex -S mix phx.server
config = Application.get_env(:ehs_enforcement, :github_admin)
config[:allowed_users]
```

### Default Admin

```
Username: shotleybuilder
Login URL (dev): http://localhost:4002/admin
Login URL (prod): https://legal.sertantai.com/admin
```

---

## Related Documentation

- [Configuration Management Guide](configuration_management.md) - System configuration
- [Scraping Overview](scraping_overview.md) - Admin dashboard overview
- [Import & Sync Guide](import_sync_guide.md) - Data synchronization

---

**Last Updated**: 2025-10-16
