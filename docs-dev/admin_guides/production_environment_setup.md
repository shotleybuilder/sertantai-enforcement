# Production Environment Setup

This guide explains how to configure environment variables for production deployment, especially after moving to shared infrastructure.

## Quick Validation

Before deployment, validate your environment configuration:

```bash
# In production environment, run:
mix validate_env
```

This will check all required and optional variables and provide a detailed report.

## Required Environment Variables

These variables **must** be set in production. The application will fail to start without them.

### Authentication & Security

```bash
# GitHub OAuth Application Credentials
# Create at: https://github.com/settings/developers
GITHUB_CLIENT_ID=your_github_oauth_client_id
GITHUB_CLIENT_SECRET=your_github_oauth_client_secret

# Token Signing Secret (generate with: mix phx.gen.secret)
TOKEN_SIGNING_SECRET=your_long_random_secret_here

# Phoenix Secret Key Base (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your_long_random_secret_key_base_here
```

### Database

```bash
# PostgreSQL connection string
DATABASE_URL=ecto://user:password@hostname:5432/database_name

# Optional: Connection pool size (default: 10)
POOL_SIZE=10
```

## Admin Authorization Configuration

**At least one method must be configured** for admin features to work. Choose the method that best fits your team structure.

### Method 1: Allow List (Recommended for Small Teams)

Explicitly list GitHub usernames who should have admin access:

```bash
# Comma-separated list of GitHub usernames
GITHUB_ALLOWED_USERS=username1,username2,username3
```

**Pros:**
- Simple to configure
- No API token required
- Easy to manage for small teams

**Cons:**
- Requires manual updates when team changes
- No automatic synchronization with GitHub

### Method 2: Repository-Based (Recommended for Large Teams)

Automatically grant admin access to GitHub repository collaborators:

```bash
# Repository details
GITHUB_REPO_OWNER=your-org-or-username
GITHUB_REPO_NAME=your-repo-name

# Personal Access Token with 'repo:read' scope
# Create at: https://github.com/settings/tokens
GITHUB_ACCESS_TOKEN=ghp_your_personal_access_token
```

**Pros:**
- Automatic synchronization with GitHub team
- No manual updates needed
- Scales well for larger teams

**Cons:**
- Requires personal access token
- Token needs 'repo:read' scope

## Optional Environment Variables

These have sensible defaults but can be customized:

```bash
# OAuth redirect URI (defaults to https://{PHX_HOST}/auth/user/github/callback)
GITHUB_REDIRECT_URI=https://yourdomain.com/auth/user/github/callback

# Host for URL generation (defaults to example.com)
PHX_HOST=yourdomain.com

# Server port (defaults to 4002)
PORT=4002

# Enable server on startup (defaults to false, set for production)
PHX_SERVER=true
```

## Troubleshooting

### Issue: "Admin Dashboard" label doesn't appear after sign-in

**Diagnosis:**
1. User successfully authenticated via GitHub OAuth
2. User redirected to homepage
3. No "ADMIN DASHBOARD" label in navigation

**Solution:**
Verify admin authorization is configured using one of the two methods above.

**Quick Check:**
```bash
# Check if allow list is set
echo $GITHUB_ALLOWED_USERS

# OR check if repository-based config is complete
echo $GITHUB_REPO_OWNER
echo $GITHUB_REPO_NAME
echo $GITHUB_ACCESS_TOKEN
```

If all variables are empty or incomplete, admin authorization is not configured.

### Issue: "Internal Server Error" on logout

**Diagnosis:**
Logout fails with 500 error when trying to revoke authentication tokens.

**Root Causes:**
1. `TOKEN_SIGNING_SECRET` is missing or different from the secret used during sign-in
2. Database connection issues preventing token revocation
3. Token resource not properly configured

**Solutions:**

1. **Verify TOKEN_SIGNING_SECRET is set:**
   ```bash
   echo $TOKEN_SIGNING_SECRET
   ```
   If empty, generate and set it:
   ```bash
   mix phx.gen.secret
   # Copy output and set as TOKEN_SIGNING_SECRET
   ```

2. **Ensure TOKEN_SIGNING_SECRET is consistent:**
   - Must be the same value across all app instances
   - Must not change between deployments
   - Store securely in your deployment platform

3. **Check database connectivity:**
   ```bash
   psql $DATABASE_URL -c "SELECT 1;"
   ```

4. **Apply the logout error handling fix:**
   The fix in `lib/ehs_enforcement_web/controllers/auth_controller.ex` makes logout gracefully
   handle token revocation errors. Deploy this change to production.

### Issue: Different behavior between dev and production

**Common Causes:**
1. Environment variables not properly migrated to shared infrastructure
2. TOKEN_SIGNING_SECRET differs between environments (causes token validation failures)
3. Database connection differences

**Migration Checklist:**
- [ ] All required environment variables set in production
- [ ] TOKEN_SIGNING_SECRET is consistent (or explicitly rotated)
- [ ] GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET match the production OAuth app
- [ ] GITHUB_REDIRECT_URI matches the production domain
- [ ] Admin authorization method is configured
- [ ] DATABASE_URL is correct for production database

## Deployment Checklist

Before deploying to production:

1. **Generate Secrets:**
   ```bash
   # Generate TOKEN_SIGNING_SECRET
   mix phx.gen.secret

   # Generate SECRET_KEY_BASE
   mix phx.gen.secret
   ```

2. **Create GitHub OAuth App:**
   - Go to https://github.com/settings/developers
   - Create new OAuth App
   - Set Authorization callback URL to: `https://yourdomain.com/auth/user/github/callback`
   - Copy Client ID and Client Secret

3. **Configure Admin Access:**
   - Choose Method 1 (allow list) or Method 2 (repository-based)
   - Set appropriate environment variables

4. **Set All Environment Variables:**
   ```bash
   # On your deployment platform (e.g., Render, Fly.io, Heroku)
   GITHUB_CLIENT_ID=...
   GITHUB_CLIENT_SECRET=...
   TOKEN_SIGNING_SECRET=...
   SECRET_KEY_BASE=...
   DATABASE_URL=...

   # Choose one admin method:
   GITHUB_ALLOWED_USERS=user1,user2  # OR
   GITHUB_REPO_OWNER=...
   GITHUB_REPO_NAME=...
   GITHUB_ACCESS_TOKEN=...

   # Optional:
   PHX_HOST=yourdomain.com
   GITHUB_REDIRECT_URI=https://yourdomain.com/auth/user/github/callback
   PHX_SERVER=true
   ```

5. **Validate Configuration:**
   ```bash
   mix validate_env
   ```

6. **Deploy:**
   ```bash
   # Deploy to your platform
   git push production main  # or equivalent
   ```

7. **Test Authentication:**
   - Sign in with GitHub
   - Verify admin dashboard appears (if you're in the admin list)
   - Test logout functionality

## Security Best Practices

1. **Never commit secrets to version control**
   - Secrets should only exist in environment variables
   - Use `.env.local` for local development (already gitignored)

2. **Rotate secrets periodically**
   - Generate new TOKEN_SIGNING_SECRET
   - Update in all production instances simultaneously
   - Note: This will invalidate all existing sessions

3. **Limit GitHub token scope**
   - Use minimum required scopes
   - Repository-based method only needs `repo:read`

4. **Monitor admin access**
   - Regularly review GITHUB_ALLOWED_USERS
   - Audit repository collaborators if using Method 2

## Reference

For more information, see:
- [CLAUDE.md](../../CLAUDE.md) - Main development guidelines
- [Authentication Guide](authentication.md) - Detailed authentication documentation
- [Configuration Management](configuration_management.md) - General config guidelines
