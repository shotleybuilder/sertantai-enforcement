# Production Environment Variables Checklist

Quick reference for setting up production environment after infrastructure migration.

## ✅ Action Items

### 1. Validate Current Configuration

```bash
mix validate_env
```

### 2. Required Variables (Application Will Fail Without These)

```bash
GITHUB_CLIENT_ID=___________________
GITHUB_CLIENT_SECRET=_______________
TOKEN_SIGNING_SECRET=_______________  # Generate: mix phx.gen.secret
SECRET_KEY_BASE=____________________  # Generate: mix phx.gen.secret
DATABASE_URL=_______________________
```

### 3. Admin Configuration (Choose ONE Method)

**Method A: Simple Allow List** (Recommended)
```bash
GITHUB_ALLOWED_USERS=username1,username2,username3
```

**Method B: Repository-Based**
```bash
GITHUB_REPO_OWNER=__________________
GITHUB_REPO_NAME=___________________
GITHUB_ACCESS_TOKEN=________________  # Create at github.com/settings/tokens
```

### 4. Optional Variables

```bash
GITHUB_REDIRECT_URI=https://yourdomain.com/auth/user/github/callback  # (if custom)
PHX_HOST=yourdomain.com  # (defaults to example.com)
PHX_SERVER=true  # (required for production startup)
PORT=4002  # (defaults to 4002)
```

## 🔍 Quick Diagnosis

### Symptom: Logout gives "Internal Server Error"
**Cause:** Missing or incorrect `TOKEN_SIGNING_SECRET`

**Fix:**
1. Generate secret: `mix phx.gen.secret`
2. Set `TOKEN_SIGNING_SECRET` environment variable
3. Ensure it's the same value used during sign-in

### Symptom: No "ADMIN DASHBOARD" label after successful sign-in
**Cause:** Admin configuration not set

**Fix:**
Set either:
- `GITHUB_ALLOWED_USERS=your_github_username` (Method A), OR
- All three variables for Method B (`GITHUB_REPO_OWNER`, `GITHUB_REPO_NAME`, `GITHUB_ACCESS_TOKEN`)

## 🚀 Deployment Steps

1. **Generate secrets locally:**
   ```bash
   mix phx.gen.secret  # For TOKEN_SIGNING_SECRET
   mix phx.gen.secret  # For SECRET_KEY_BASE
   ```

2. **Set environment variables in your deployment platform**

3. **Run validation:**
   ```bash
   mix validate_env
   ```

4. **Deploy the logout fix** (already implemented in `lib/ehs_enforcement_web/controllers/auth_controller.ex`)

5. **Test:**
   - Sign in with GitHub ✓
   - Verify admin dashboard appears (if configured as admin) ✓
   - Test logout ✓

## 📚 Full Documentation

See [docs-dev/admin_guides/production_environment_setup.md](docs-dev/admin_guides/production_environment_setup.md) for detailed information.

## 🆘 Need Help?

Run the validation tool with detailed output:
```bash
mix validate_env
```

This will tell you exactly which variables are missing or misconfigured.
