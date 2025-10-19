# Docker Build Cache Detection Plan

**Created:** 2025-10-18
**Status:** Planning
**Priority:** High (prevents production deployment issues)

---

## Problem Statement

When compile-time configuration files (like `config/prod.exs`) are changed, Docker's layer cache can prevent those changes from being included in the built image. This leads to:

- ✅ Application starts successfully
- ❌ Configuration changes don't take effect
- ❌ Production behaves as if old config is still active
- ❌ No errors in logs (silent failure)

**Real-world example from 2025-10-18:**
- Changed `config/prod.exs` to add `force_ssl: true`
- Built image with `./scripts/deployment/build.sh` (used cache)
- Deployed to production
- App started but session cookies didn't have `secure: true` flag
- Required rebuild with `./scripts/deployment/build-cacheless.sh`

---

## Goal

Add automated detection to deployment scripts that warns developers when:
1. Config files have changed but cached build might be used
2. Local config doesn't match deployed image config
3. Image was built before config files were modified

---

## Proposed Solutions

### Option 1: Pre-Build Config Change Detection

**Difficulty:** Low
**Effectiveness:** Medium
**Maintenance:** Low

Add to `build.sh` before building:

```bash
#!/bin/bash

# Check if config files changed in recent commits
CONFIG_CHANGED=$(git diff --name-only HEAD~1 HEAD | grep -E "^config/(prod|config)\.exs$" || true)

if [ -n "$CONFIG_CHANGED" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  WARNING: Compile-time config files changed!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Changed files: $CONFIG_CHANGED"
  echo ""
  echo "These files are copied at build time and changes require"
  echo "a clean build with --no-cache to take effect."
  echo ""
  echo "Recommended: ./scripts/deployment/build-cacheless.sh"
  echo ""
  read -p "Continue with cached build? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Build cancelled. Use build-cacheless.sh for clean build."
    exit 1
  fi
  echo ""
  echo "⚠️  Proceeding with cached build (changes may not be included!)"
  echo ""
fi
```

**Pros:**
- ✅ Simple to implement
- ✅ Catches changes in recent commits
- ✅ No Dockerfile modifications needed
- ✅ Interactive - asks user what to do

**Cons:**
- ❌ Only detects changes in last commit
- ❌ Misses uncommitted changes
- ❌ Can't verify what's actually in the image

**When it works:**
- Developer commits config changes
- Builds immediately after commit
- Git history is clean

**When it fails:**
- Multiple commits since config change
- Uncommitted config changes
- Config changed in earlier commit but cached build persists

---

### Option 2: Embed Config Hash in Image

**Difficulty:** Medium
**Effectiveness:** High
**Maintenance:** Medium

**Step 1:** Modify `Dockerfile` to embed config hash:

```dockerfile
# After: COPY config/config.exs config/prod.exs config/
RUN sha256sum config/prod.exs config/config.exs | sort > /app/config_hash.txt
```

**Step 2:** Add verification to `deploy-prod.sh` before deploying:

```bash
#!/bin/bash

echo ""
echo "Verifying config consistency..."
echo ""

# Get current local config hash
LOCAL_HASH=$(sha256sum config/prod.exs config/config.exs 2>/dev/null | sort)

# Get deployed image config hash
DEPLOYED_HASH=$(docker run --rm ghcr.io/shotleybuilder/ehs-enforcement:latest cat /app/config_hash.txt 2>/dev/null | sort || echo "none")

if [ "$LOCAL_HASH" != "$DEPLOYED_HASH" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🚨 WARNING: Config Mismatch!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "The config files in the Docker image don't match local files."
  echo "This usually means Docker cache was used when it shouldn't be."
  echo ""
  echo "Local config hash:"
  echo "$LOCAL_HASH" | sed 's/^/  /'
  echo ""
  echo "Image config hash:"
  echo "$DEPLOYED_HASH" | sed 's/^/  /'
  echo ""
  echo "Solutions:"
  echo "  1. Rebuild with: ./scripts/deployment/build-cacheless.sh"
  echo "  2. Push new image: ./scripts/deployment/push.sh"
  echo "  3. Then try deploy again"
  echo ""
  read -p "Continue deployment anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Deployment cancelled for safety."
    exit 1
  fi
  echo ""
  echo "⚠️  Proceeding with mismatched config (NOT RECOMMENDED!)"
  echo ""
fi
```

**Step 3 (Optional):** Add to `push.sh` as well:

```bash
# Before pushing, verify config hash exists
if ! docker run --rm ghcr.io/shotleybuilder/ehs-enforcement:latest cat /app/config_hash.txt &>/dev/null; then
  echo "⚠️  WARNING: Image doesn't contain config hash"
  echo "   This might be an old image format"
fi
```

**Pros:**
- ✅ Catches exact mismatch between local and deployed config
- ✅ Works regardless of git history
- ✅ Verifies at deployment time (last safety check)
- ✅ Shows exactly what's different

**Cons:**
- ❌ Requires Dockerfile modification
- ❌ Adds small build overhead
- ❌ Requires rebuilding all existing images to add hash
- ❌ Won't help if image was built elsewhere

**When it works:**
- Every time - most robust solution
- Catches any config mismatch
- Independent of git state

**When it fails:**
- Old images without embedded hash
- External builds (CI/CD without hash)

---

### Option 3: Docker Image Timestamp Check

**Difficulty:** Low
**Effectiveness:** Medium
**Maintenance:** Low

Add to `build.sh` before building:

```bash
#!/bin/bash

# Check if config files were modified after image was built
check_config_timestamps() {
  # Get config file modification time
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    PROD_MTIME=$(stat -f %m config/prod.exs 2>/dev/null)
    CONFIG_MTIME=$(stat -f %m config/config.exs 2>/dev/null)
  else
    # Linux
    PROD_MTIME=$(stat -c %Y config/prod.exs 2>/dev/null)
    CONFIG_MTIME=$(stat -c %Y config/config.exs 2>/dev/null)
  fi

  LATEST_CONFIG_MTIME=$PROD_MTIME
  if [ "$CONFIG_MTIME" -gt "$LATEST_CONFIG_MTIME" ]; then
    LATEST_CONFIG_MTIME=$CONFIG_MTIME
  fi

  # Check if image exists
  IMAGE_EXISTS=$(docker images -q ghcr.io/shotleybuilder/ehs-enforcement:latest)

  if [ -n "$IMAGE_EXISTS" ]; then
    # Get image creation timestamp
    IMAGE_CREATED=$(docker inspect ghcr.io/shotleybuilder/ehs-enforcement:latest --format='{{.Created}}')

    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS date parsing
      IMAGE_TIMESTAMP=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${IMAGE_CREATED:0:19}" +%s 2>/dev/null)
    else
      # Linux date parsing
      IMAGE_TIMESTAMP=$(date -d "$IMAGE_CREATED" +%s 2>/dev/null)
    fi

    if [ "$LATEST_CONFIG_MTIME" -gt "$IMAGE_TIMESTAMP" ]; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "⚠️  WARNING: Config modified AFTER last image build!"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "Config files modified: $(date -r $LATEST_CONFIG_MTIME 2>/dev/null || date -d @$LATEST_CONFIG_MTIME)"
      echo "Image last built:      $(date -r $IMAGE_TIMESTAMP 2>/dev/null || date -d @$IMAGE_TIMESTAMP)"
      echo ""
      echo "Your changes won't be in the cached image."
      echo "Recommendation: ./scripts/deployment/build-cacheless.sh"
      echo ""
      read -p "Continue with potentially stale image? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
      fi
      echo ""
      echo "⚠️  Using existing image (config changes NOT included!)"
      echo ""
    fi
  fi

  return 0
}

# Call the check
if ! check_config_timestamps; then
  exit 1
fi
```

**Pros:**
- ✅ No Dockerfile changes needed
- ✅ Good heuristic for most cases
- ✅ Works with uncommitted changes
- ✅ Cross-platform (macOS + Linux)

**Cons:**
- ❌ Timestamps can be unreliable (git checkout changes them)
- ❌ Doesn't verify actual image contents
- ❌ Can give false positives
- ❌ Timezone issues on some systems

**When it works:**
- Normal development workflow
- Linear git history
- Single developer machine

**When it fails:**
- After git operations that touch files
- Across different machines/timezones
- With file system issues

---

### Option 4: Simple Interactive Prompt

**Difficulty:** Very Low
**Effectiveness:** Low (relies on human memory)
**Maintenance:** Very Low

Add to `build.sh` at the start:

```bash
#!/bin/bash

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Docker Build - Config Cache Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for recent config changes
if git diff --name-only $(git log -1 --format=%H) HEAD | grep -q "config/prod.exs"; then
  echo "⚠️  ALERT: config/prod.exs has uncommitted changes"
  echo ""
fi

if git diff --name-only HEAD~1 HEAD | grep -q "config/prod.exs"; then
  echo "ℹ️  NOTE: config/prod.exs was modified in last commit"
  echo ""
fi

echo "Did you change compile-time config (config/prod.exs)?"
echo ""
echo "If YES, you should use: ./scripts/deployment/build-cacheless.sh"
echo "If NO, cached build is fine"
echo ""
read -p "Proceed with cached build? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo ""
  echo "Build cancelled. Use build-cacheless.sh for clean build."
  exit 1
fi
echo ""
```

**Pros:**
- ✅ Extremely simple
- ✅ No complex logic
- ✅ Makes developers think about it
- ✅ Easy to maintain

**Cons:**
- ❌ Relies on developer memory/honesty
- ❌ Doesn't actually verify anything
- ❌ Can be skipped accidentally
- ❌ Annoying if building frequently

**When it works:**
- Developer remembers what they changed
- Single developer workflow
- Infrequent deployments

**When it fails:**
- Developer forgets what they changed
- Multiple developers
- Frequent builds

---

## Recommended Implementation: Hybrid Approach

**Combine Options 1 + 3 for best coverage with minimal complexity:**

### Phase 1: Build Script Enhancement

Add to `build.sh`:

1. Git diff check (Option 1) - catches recent commits
2. Timestamp check (Option 3) - catches all modifications
3. Interactive prompts for safety

### Phase 2: Deployment Script Enhancement

Add to `deploy-prod.sh`:

1. Final warning if image is old
2. Optional: config hash check (if Option 2 is implemented)

### Phase 3 (Optional): Full Hash Verification

If timestamp checks prove unreliable:
1. Implement Option 2 (embed hash in Dockerfile)
2. Add verification to all deployment scripts

---

## Implementation Checklist

### Immediate (Required)
- [ ] Add git diff check to `build.sh`
- [ ] Add timestamp check to `build.sh`
- [ ] Add interactive prompts with clear warnings
- [ ] Test on both Linux and macOS
- [ ] Update `build-cacheless.sh` to skip checks (since it forces clean build)

### Short-term (Nice to have)
- [ ] Add similar check to `push.sh` (warn before pushing stale image)
- [ ] Add final verification to `deploy-prod.sh`
- [ ] Add colored output for warnings (yellow/red)
- [ ] Log check results for debugging

### Long-term (Optional)
- [ ] Implement Option 2 (config hash embedding)
- [ ] Add CI/CD integration
- [ ] Create `verify-config.sh` standalone tool
- [ ] Add metrics/logging for how often this catches issues

---

## Example Output

### When config changed (should use cacheless):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EHS Enforcement - Docker Build
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  WARNING: Compile-time config files changed!

Changed files: config/prod.exs

Config files modified: 2025-10-18 14:30:00
Image last built:      2025-10-18 12:15:00

These files are copied at build time and changes require
a clean build with --no-cache to take effect.

Recommended: ./scripts/deployment/build-cacheless.sh

Continue with cached build? (y/N) n

Build cancelled. Use build-cacheless.sh for clean build.
```

### When config unchanged (safe to use cache):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EHS Enforcement - Docker Build
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ No config changes detected
✓ Config files older than existing image

Proceeding with cached build...
```

---

## Testing Strategy

### Manual Testing

1. **Test Case 1: No Changes**
   ```bash
   ./scripts/deployment/build.sh
   # Should: Proceed normally, no warnings
   ```

2. **Test Case 2: Config Just Changed**
   ```bash
   echo "# comment" >> config/prod.exs
   git add config/prod.exs
   git commit -m "test config change"
   ./scripts/deployment/build.sh
   # Should: Show warning, offer cacheless build
   ```

3. **Test Case 3: Old Cached Image**
   ```bash
   # Build image
   ./scripts/deployment/build.sh
   # Wait or touch config
   touch config/prod.exs
   ./scripts/deployment/build.sh
   # Should: Detect timestamp mismatch, warn
   ```

4. **Test Case 4: Using build-cacheless.sh**
   ```bash
   echo "# comment" >> config/prod.exs
   ./scripts/deployment/build-cacheless.sh
   # Should: Skip all checks, proceed with clean build
   ```

### Automated Testing

```bash
# Create test script: scripts/test-cache-detection.sh
#!/bin/bash

set -e

echo "Testing cache detection logic..."

# Test 1: Fresh state
./scripts/deployment/build.sh <<< "y"

# Test 2: Touch config
sleep 2
touch config/prod.exs
! ./scripts/deployment/build.sh <<< "n"  # Should fail (user said no)

# Test 3: Cacheless build
./scripts/deployment/build-cacheless.sh

echo "All tests passed!"
```

---

## Risks and Mitigation

### Risk 1: False Positives

**Risk:** Script warns when no actual cache problem exists
**Impact:** Developer annoyance, wasted time
**Mitigation:**
- Make warnings clear and specific
- Provide easy override (press 'y')
- Log false positives for analysis

### Risk 2: False Negatives

**Risk:** Script doesn't catch actual cache problem
**Impact:** Deployment with stale config (critical!)
**Mitigation:**
- Use multiple detection methods (git + timestamp)
- Add deployment-time verification
- Consider Option 2 (hash embedding) for critical configs

### Risk 3: Cross-Platform Issues

**Risk:** Different behavior on macOS vs Linux
**Impact:** Inconsistent developer experience
**Mitigation:**
- Test on both platforms
- Use portable commands
- Provide OS-specific fallbacks

### Risk 4: Git Workflow Conflicts

**Risk:** Doesn't work well with certain git workflows
**Impact:** Warnings on every build
**Mitigation:**
- Make checks optional via environment variable
- Provide `--skip-checks` flag
- Document workflow requirements

---

## Alternative: Build Arguments Approach

Instead of caching detection, prevent caching of config layer:

```dockerfile
# In Dockerfile:
ARG CONFIG_BUST_CACHE=unknown
RUN echo "Config cache bust: $CONFIG_BUST_CACHE"
COPY config/config.exs config/prod.exs config/
```

Then in build script:
```bash
docker build \
  --build-arg CONFIG_BUST_CACHE=$(date +%s) \
  -t ghcr.io/shotleybuilder/ehs-enforcement:latest .
```

**Pros:** Forces fresh config copy every build
**Cons:** Slower builds, invalidates more cache than needed

---

## Conclusion

Recommended path forward:

1. **Week 1:** Implement hybrid Option 1 + 3 in `build.sh`
2. **Week 2:** Add deployment-time checks to `deploy-prod.sh`
3. **Week 3:** Test and refine based on real usage
4. **Later:** Consider Option 2 if timestamp/git checks prove unreliable

This provides good protection against cache issues while keeping implementation complexity low.

---

**Status:** Ready for implementation
**Next Steps:** Review with team, begin Week 1 implementation
**Documentation:** Update DEPLOYMENT_WITH-SCRIPTS.md with new checks
