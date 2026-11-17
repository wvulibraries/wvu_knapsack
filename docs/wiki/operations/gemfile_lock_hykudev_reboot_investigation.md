# Investigation: Why Gemfile.lock Preservation Prevents hykudev Reboots

**Category:** Operations / Root Cause Analysis  
**Date Created:** 2026-11-17  
**Status:** Investigation In Progress  
**Related Issue:** hykudev rebooted continuously during 7.2.0 upgrade testing until Gemfile.lock was copied from prod

---

## The Symptom

During the 7.2.0 upgrade testing on hykudev:
- **Without prod's Gemfile.lock:** Container kept crashing/rebooting
- **After copying Gemfile.lock from prod:** Container stayed up and functional
- **Same SHA on hyrax-webapp submodule** as production, but build behavior differed

---

## Why This Happens: Fresh Bundle Install Behavior

When Docker builds without a lockfile and encounters a submodule update:

```dockerfile
# From Dockerfile line 32
COPY Gemfile* /app/samvera/

# Then later
RUN bundle install --jobs "$(nproc)"
```

**Without Gemfile.lock:**
1. Bundler resolves all dependencies from scratch (Gemfile + hyrax-webapp/Gemfile)
2. Resolution picks the **latest compatible versions** at build time
3. These versions may differ from what prod deployed (which has locked versions)

**With Gemfile.lock (from prod):**
1. Bundler uses exact pinned versions
2. Resolution is deterministic — same result every build
3. No surprises from newer gem versions

---

## Why Fresh Resolution Failed During 7.2.0

The 7.2.0 upgrade introduced several compatibility issues that required specific gem versions:

### Issue 1: NameError on Boot
**Commit:** `c8ccf24` (Guard Hyku VERSION constants)

```
Error: NameError: uninitialized constant Hyku::ORIGINAL_VERSION
```

This crashed the web container during initialization in the knapsack initializer.

**Why fresh resolution caused it:**
- Fresh gem install brought in Hyku 7.2.0 from the submodule
- The zzz_temporary_hyku_version_override initializer tried to access constants
- Those constants weren't loaded in the right order during fresh boot
- Prod's locked Gemfile.lock avoided this by having gems installed in a known order

### Issue 2: Gem Dependency Conflicts During Resolution
When resolving fresh with hyrax-webapp's 7.2.0 Gemfile:

**Likely culprits (based on 7.2 upgrade branch fixes):**
- `omniauth-saml` compatibility with current-phase patch
- Blacklight 7+ vs 8+ version differences
- Rails 7.2.0 gem constraints
- Flexible metadata framework changes

**What happened:**
1. Fresh `bundle install` picks latest compatible versions
2. Some combo of gems are incompatible (breaking dependency)
3. Bundle fails to resolve, OR resolution succeeds but gems have issues
4. Container fails to boot with missing constants/methods

### Issue 3: Why Prod's Copy Works
Production's Gemfile.lock has:
- ✅ Versions that **are known to work together**
- ✅ Been tested in production deployment
- ✅ All gems loaded and started successfully
- ✅ No NameError or missing constant crashes

When you copy it and use those exact pinned versions, hykudev uses the **same proven gem set**.

---

## The Deeper Issue: Gem Resolution Divergence

The real root cause isn't Gemfile.lock policy — it's that:

1. **Prod deploys rarely start from scratch**
   - Prod typically rolls forward (update submodule, existing gems stay)
   - Fresh resolution isn't tested regularly on prod

2. **Local/hykudev rebuilds from scratch**
   - Every `docker compose build --no-cache` runs `bundle install` fresh
   - Fresh resolution can pick different versions than prod's historical rollout

3. **Gem versions can have breaking changes**
   - Major version bumps remove constants, change APIs
   - 7.2.0 upgrade brings in potentially incompatible gem versions
   - Prod's locked set was tested; fresh resolution wasn't

---

## Why This Will Keep Happening

**Unless we lock Gemfile.lock, fresh builds on 7.2 upgrades will:**
- Continue to resolve unpredictably
- May pick gem versions incompatible with Hyku 7.2
- Cause container crashes on startup
- Require copying from prod to get known-good versions

**The fix options:**

1. **Keep Gemfile.lock committed** (best, ensures reproducibility)
2. **Keep local backup + document the exact gem conflicts** (what we did)
3. **Pin critical gems in Gemfile** (partial fix, still fragile)
4. **Test fresh resolution thoroughly on dev before deploying** (time-consuming)

---

## Action Items

1. ✅ Document this analysis (done)
2. Next: When you test 7.2.0 locally, capture any gem resolution errors
3. If build fails with fresh Gemfile.lock resolution, use the backup
4. Document exactly which gems caused the conflict
5. Consider if Gemfile.lock locking is worth the safety gain
