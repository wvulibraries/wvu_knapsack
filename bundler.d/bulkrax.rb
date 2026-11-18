# frozen_string_literal: true
# WVU Knapsack Bulkrax Override
#
# Force bulkrax to 10.0.1 to get critical metadata separator handling fixes.
# This addresses the issue where colons AND semicolons were acting as separators
# when only semicolons should be used (reported by Sarah / ACDAP issue).
#
# See: https://github.com/samvera/bulkrax/releases/tag/v10.0.1

override_gem 'bulkrax', '10.0.1'
