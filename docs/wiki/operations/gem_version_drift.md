# Gem Version Drift in Hyku Builds

**Category:** Operations  
**Date Created:** 2026-11-17  
**Related:** [Debugging Strategy](./debugging_strategy.md)

## The Problem

When `Gemfile.lock` is not committed to the repository, different build times resolve gems independently. This can produce incompatible gem versions across environments (local, dev, hykudev, production).

### Example Incident

- Dev environment resolved `blacklight_advanced_search 8.1.0`
- Production had `blacklight_advanced_search 7.0.0`
- v8.x removed the `RenderConstraintsOverride` constant
- Hyrax v7.1.3 controller still referenced it at class load time
- **Result:** NameError crashed the web container before any Rails code ran

## Root Cause

Gem resolution happens at container build time, **before** any Rails code runs. Different gem versions mean different constants and methods are available. This manifests as a code bug when the real issue is a dependency mismatch.

## Prevention

### Option A: Commit Gemfile.lock (Recommended)

```bash
git add Gemfile.lock && git commit -m "lock: Pin gem versions for reproducible builds"
```

This locks all gem versions and ensures every environment resolves identically.

### Option B: Pin Critical Gems in Gemfile

After the submodule eval, pin specific gems:

```ruby
eval_gemfile 'hyrax-webapp/Gemfile'
gem 'blacklight', '~> 7.41.0'
gem 'blacklight_advanced_search', '~> 7.0.0'
```

## Diagnosing Gem Drift

Symptoms that suggest gem drift rather than a code bug:

- Web container crashes on startup with NameError or MissingConstantError
- Error references a constant/method that exists in the source code
- Different environments behave differently for the same code
- Issue appeared after a dependency update (even if not directly related)

## Testing Gem Changes

1. Always test locally with Stack Car after updating Gemfile
2. Run `bundle install` to verify resolution succeeds
3. Check gem change logs for removed constants/methods
4. Verify all environments resolve to the same versions
