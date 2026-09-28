#!/usr/bin/env rails runner

# Verification script for M3 facet limiting
# Run: cd /path/to/wvu_knapsack && rails runner script/verify_facet_limits.rb
# Or from Docker: docker exec wvu_knapsack-web-1 rails runner script/verify_facet_limits.rb

puts "\n=== FACET LIMIT VERIFICATION ==="
puts "Date: #{Time.now}"
puts "Rails env: #{Rails.env}\n"

# 1. Check Blacklight configuration
puts "1. BLACKLIGHT FACET CONFIGURATION"
puts "-" * 60

if defined?(::CatalogController)
  config = CatalogController.blacklight_config
  
  puts "Default facet limit: #{config.default_facet_limit.inspect}"
  puts "Total facets registered: #{config.facet_fields.size}\n"
  
  # List all facets with their settings
  config.facet_fields.each do |field_name, facet_config|
    limit = facet_config.limit.inspect
    show_more = facet_config.show_more.inspect
    label = facet_config.label.inspect rescue "N/A"
    
    marker = field_name.to_s.end_with?('_sim') ? "[M3]" : "[CORE]"
    
    puts "#{marker} #{field_name.ljust(30)} limit: #{limit.ljust(6)} show_more: #{show_more.ljust(6)} label: #{label}"
  end
  
  puts "\n[M3] = M3 flexible-metadata facet"
  puts "[CORE] = Core/hard-coded facet"
else
  puts "ERROR: CatalogController not defined"
  exit 1
end

# 2. Check for essential M3 facets
puts "\n2. M3 FLEXIBLE METADATA FACETS"
puts "-" * 60

m3_fields = %w[date_created_sim people_represented_sim based_near_label_sim location_sim]
m3_fields.each do |field|
  if config.facet_fields.key?(field)
    fc = config.facet_fields[field]
    limit = fc.limit
    status = limit == 5 ? "✓ OK" : "✗ WRONG (#{limit})"
    puts "#{field.ljust(35)} #{status}"
  else
    puts "#{field.ljust(35)} ✗ NOT REGISTERED"
  end
end

# 3. Test search builder
puts "\n3. SEARCH BUILDER FACET PARAMS"
puts "-" * 60

begin
  require 'blacklight/solr/repository'
  
  # Create a mock controller instance
  controller = CatalogController.new
  controller.request = ActionController::TestRequest.create
  controller.response = ActionDispatch::Response.new
  
  # Build search params
  builder = CatalogSearchBuilder.new(controller)
  builder_params = builder.add_facetting_to_solr({})
  
  facet_params = builder_params.select { |k, v| k.to_s.start_with?('f.') && k.to_s.include?('facet.limit') }
  
  puts "Facet limit params sent to Solr:"
  facet_params.each do |key, value|
    field_name = key.to_s.gsub(/^f\./, '').gsub(/\.facet\.limit$/, '')
    puts "  #{key.ljust(50)} = #{value}"
  end
  
  if facet_params.empty?
    puts "  WARNING: No facet.limit params found!"
  else
    puts "\n✓ Search builder is sending facet.limit params"
  end
rescue => e
  puts "  ERROR: Could not test search builder: #{e.message}"
end

# 4. Summary
puts "\n4. SUMMARY"
puts "-" * 60

errors = []

# Check all facets have limit
config.facet_fields.each do |field_name, fc|
  errors << "#{field_name}: limit not set" if fc.limit.nil?
  errors << "#{field_name}: limit != 5 (got #{fc.limit})" if fc.limit && fc.limit != 5
end

# Check Type facet is hidden
if config.facet_fields.key?('generic_type_sim')
  errors << "Type facet (generic_type_sim) should be deleted"
end

# Check M3 facets exist
m3_found = config.facet_fields.select { |k, v| k.to_s.end_with?('_sim') }.size
puts "M3 facets found: #{m3_found}"
puts "Total facets: #{config.facet_fields.size}"

if errors.empty?
  puts "\n✓ ALL CHECKS PASSED - Facet limiting is correctly configured"
  puts "\nNext: Deploy to VM and test catalog page:"
  puts "  https://hykudev.lib.wvu.edu/catalog?search_field=all_fields&q="
  puts "\nVerify:"
  puts "  1. Date Created shows 5 items + 'more' link"
  puts "  2. Location shows 5 items + 'more' link"
  puts "  3. People Represented shows 5 items + 'more' link"
  puts "  4. Type facet is hidden"
else
  puts "\n✗ ERRORS FOUND:"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end

puts "\n"
