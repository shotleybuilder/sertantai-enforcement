# Legacy Scripts - DEPRECATED

This directory contains deprecated scripts that have been superseded by newer implementations.

**⚠️ WARNING: These scripts are kept for reference only and should NOT be used in production.**

---

## deploy.sh - DEPRECATED

**Status**: Superseded by `scripts/deployment/` workflow

**Original Purpose**: Generic docker-compose based deployment script

**Why Deprecated**:
- Old approach using local docker-compose builds
- Does not use GHCR image registry
- Not optimized for our production infrastructure
- Replaced by more robust deployment workflow

**Modern Replacement**:
Use the complete deployment workflow in `scripts/deployment/`:

```bash
# 1. Build Docker image
./scripts/deployment/build.sh

# 2. Push to GitHub Container Registry
./scripts/deployment/push.sh

# 3. Deploy to production
./scripts/deployment/deploy-prod.sh --migrate --logs
```

**See**: `scripts/deployment/README.md` for complete documentation

---

## Migration Path

If you're currently using `deploy.sh`:

1. **Review your deployment needs** - The old script may have been customized
2. **Transition to new workflow**:
   - Ensure you have GHCR access configured
   - Use `scripts/deployment/build.sh` to build images
   - Use `scripts/deployment/push.sh` to push to registry
   - Use `scripts/deployment/deploy-prod.sh` for production deployment
3. **Update any CI/CD pipelines** that reference the old script
4. **Update documentation** that mentions `deploy.sh`

---

## Need Help?

If you need functionality from the old script that isn't in the new workflow:
- Review `scripts/deployment/README.md` for current capabilities
- Check if your use case is covered by other scripts in `scripts/ops/`
- Consult the team if you need custom deployment logic

---

**Last Updated**: 2025-10-16
**Deprecated Date**: 2025-10-16
