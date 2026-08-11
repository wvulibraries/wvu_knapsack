# Task: Upstream Wings::ModelRegistry Defensive Checks to Hyku

**Project:** Samvera Hyku  
**Category:** Community Contribution - Defensive Improvements  
**Status:** Ready for PR  
**Estimated Effort:** 1-2 hours (research + PR + review cycle)

## Objective
Contribute defensive checks for `Wings::ModelRegistry` upstream to Hyku (and potentially Hyrax), reducing downstream maintenance burden and improving reliability across all Hyku instances.

## Background
Currently, WVU Knapsack maintains a defensive patch (`config/initializers/goddess_query_fix.rb`) that guards against `NameError: uninitialized constant Wings::ModelRegistry` in `Hyrax::Goddess::Query#model_class_for` (lib/goddess/query.rb:17).

**Why Upstream:**
- ✅ Affects all Hyku instances, not just WVU
- ✅ Defensive only — doesn't change behavior when Wings IS available
- ✅ Reduces downstream maintenance — removes need for local patch
- ✅ Community benefit — part of user's role as Hyku community developer
- ✅ Pattern established — similar to wings.rb defensive check already discussed

## Scope
Two defensive improvements, can be separate PRs or combined:

### 1. Hyrax: lib/goddess/query.rb#model_class_for
**Current Knapsack patch:**
```ruby
def model_class_for(model)
  internal_resource = model.respond_to?(:internal_resource) ? model.internal_resource : nil
  return internal_resource.safe_constantize if internal_resource&.safe_constantize
  
  if defined?(Wings::ModelRegistry)
    Wings::ModelRegistry.lookup(model)
  else
    model.is_a?(Class) ? model : model.class
  end
end
```

### 2. Hyku/Hyrax: wings.rb initialization
**Already identified in repo memory:** Defensive `if defined?(Wings::ModelRegistry)` guard around `Wings::ModelRegistry.reverse_lookup(klass)` in config/initializers/wings.rb (lines 202-206).

## Implementation Steps
1. [ ] Research current Hyrax/Hyku versions and dependency chain
2. [ ] Verify both defensive patterns are still needed (may already be fixed upstream)
3. [ ] Fork Hyku and create feature branch
4. [ ] Apply both defensive improvements
5. [ ] Write tests ensuring graceful fallback works
6. [ ] Create PR with clear description of why (fragile coupling, initialization order)
7. [ ] Address review feedback
8. [ ] Merge upstream
9. [ ] Update Knapsack to remove local goddess_query_fix.rb patch (once upstream merged and pulled)

## Acceptance Criteria
- [ ] PR opened to Hyku upstream with both defensive improvements
- [ ] Tests verify fallback behavior (Wings not available)
- [ ] PR merged to Hyku
- [ ] Hyku release includes fixes
- [ ] Knapsack submodule updated to new Hyku version
- [ ] Local goddess_query_fix.rb removed from Knapsack (no longer needed)

## Notes
- Keep local patch in Knapsack for now (until upstream merged and released)
- This is defensive improvement, not a bug fix — low risk
- Pattern improves overall resilience of initialization sequence
- Follows established Rails patterns (defined?, to_prepare hooks)

## Related Files
- **Local patch**: `/config/initializers/goddess_query_fix.rb` (commit 9a35e75)
- **Upstream target**: Hyrax gem (`lib/goddess/query.rb` and initializer files)
- **Hyku ref**: hyrax-webapp submodule in wvu_knapsack
