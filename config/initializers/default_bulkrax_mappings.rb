# frozen_string_literal: true

# This lambda is used to set the default field mapping for Bulkrax:
# conf.default_field_mapping = lambda do |field|
#   return if field.blank?
#   {
#     field.to_s =>
#     {
#       from: [field.to_s],
#       split: false,
#       parsed: Bulkrax::ApplicationMatcher.method_defined?("parse_#{field}"),
#       if: nil,
#       excluded: false
#     }
#   }
# end

## Set custom default bulkrax parser field mappings for app
parser_mappings = {
 "alt_text"=>{"from"=>["alt_text"], "split"=>true},
 "abstract"=>{"from"=>["abstract"], "split"=>true},
 "accessibility_feature"=>{"from"=>["accessibility_feature"], "split"=>"\\|"},
 "accessibility_hazard"=>{"from"=>["accessibility_hazard"], "split"=>"\\|"},
 "accessibility_summary"=>{"from"=>["accessibility_summary"]},
 "additional_information"=>{"from"=>["additional_information"], "split"=>"\\|", "generated"=>true},
 "admin_note"=>{"from"=>["admin_note"]},
 "admin_set_id"=>{"from"=>["admin_set_id"], "generated"=>true},
 "alternate_version"=>{"from"=>["alternate_version"], "split"=>"\\|"},
 "alternative_title"=>{"from"=>["alternative_title"], "split"=>"\\|", "generated"=>true},
 "arkivo_checksum"=>{"from"=>["arkivo_checksum"], "split"=>"\\|", "generated"=>true},
 "audience"=>{"from"=>["audience"], "split"=>"\\|"},
 "based_near"=>{"from"=>["location"], "split"=>"\\|"},
 "bibliographic_citation"=>{"from"=>["bibliographic_citation"], "split"=>true},
 "bulkrax_identifier"=>{"from"=>["source_identifier"], "source_identifier"=>true, "generated"=>true, "search_field"=>"bulkrax_identifier_tesim"},
 "contributor"=>{"from"=>["contributor"], "split"=>true},
 "create_date"=>{"from"=>["create_date"], "split"=>true},
 "children"=>{"from"=>["children"], "related_children_field_mapping"=>true},
 "committee_member"=>{"from"=>["committee_member"], "split"=>"\\|"},
 "creator"=>{"from"=>["creator"], "split"=>true},
 "date_created"=>{"from"=>["date_created"], "split"=>true},
 "date_uploaded"=>{"from"=>["date_uploaded"], "generated"=>true},
 "degree_discipline"=>{"from"=>["discipline"], "split"=>"\\|"},
 "degree_grantor"=>{"from"=>["grantor"], "split"=>"\\|"},
 "degree_level"=>{"from"=>["level"], "split"=>"\\|"},
 "degree_name"=>{"from"=>["degree"], "split"=>"\\|"},
 "depositor"=>{"from"=>["depositor"], "split"=>"\\|", "generated"=>true},
 "description"=>{"from"=>["description"], "split"=>true},
 "discipline"=>{"from"=>["discipline"], "split"=>"\\|"},
 "education_level"=>{"from"=>["education_level"], "split"=>"\\|"},
 "embargo_id"=>{"from"=>["embargo_id"], "generated"=>true},
 "extent"=>{"from"=>["extent"], "split"=>true},
 "file"=>{"from"=>["file"], "split"=>/\s*[|]\s*/},
 "identifier"=>{"from"=>["identifier"], "split"=>true},
 "import_url"=>{"from"=>["import_url"], "split"=>"\\|", "generated"=>true},
 "keyword"=>{"from"=>["keyword"], "split"=>true},
 "label"=>{"from"=>["label"], "generated"=>true},
 "language"=>{"from"=>["language"], "split"=>true},
 "lease_id"=>{"from"=>["lease_id"], "generated"=>true},
 "library_catalog_identifier"=>{"from"=>["library_catalog_identifier"], "split"=>"\\|"},
 "license"=>{"from"=>["license"], "split"=>/\s*[|]\s*/},
 "modified_date"=>{"from"=>["modified_date"], "split"=>true},
 "newer_version"=>{"from"=>["newer_version"], "split"=>"\\|"},
 "oer_size"=>{"from"=>["oer_size"], "split"=>"\\|"},
 "on_behalf_of"=>{"from"=>["on_behalf_of"], "generated"=>true},
 "owner"=>{"from"=>["owner"], "generated"=>true},
 "parents"=>{"from"=>["parents"], "related_parents_field_mapping"=>true},
 "people_represented"=>{"from"=>["people_represented"], "split"=>true},
 "policy_area"=>{"from"=>["policy_area"], "split"=>true},
 "previous_version"=>{"from"=>["previous_version"], "split"=>"\\|"},
 "publisher"=>{"from"=>["publisher"], "split"=>true},
 "related_item"=>{"from"=>["related_item"], "split"=>"\\|"},
 "relative_path"=>{"from"=>["relative_path"], "split"=>"\\|", "generated"=>true},
 "related_url"=>{"from"=>["related_url", "relation"], "split"=>/\s* [|]\s*/},
 "remote_files"=>{"from"=>["remote_files"], "split"=>/\s*[|]\s*/},
 "rendering_ids"=>{"from"=>["rendering_ids"], "split"=>"\\|", "generated"=>true},
 "resource_type"=>{"from"=>["resource_type"], "split"=>true},
 "rights_holder"=>{"from"=>["rights_holder"], "split"=>"\\|"},
 "rights_notes"=>{"from"=>["rights_notes"], "split"=>true},
 "rights_statement"=>{"from"=>["rights", "rights_statement"], "split"=>"\\|", "generated"=>true},
 "source"=>{"from"=>["source"], "split"=>true},
 "state"=>{"from"=>["state"], "generated"=>true},
 "subject"=>{"from"=>["subject"], "split"=>true},
 "table_of_contents"=>{"from"=>["table_of_contents"], "split"=>"\\|"},
 "title"=>{"from"=>["title"], "split"=>/\s*[|]\s*/},
 "video_embed"=>{"from"=>["video_embed"]}
}

# # all parsers use the same mappings:
mappings = {}
mappings["Bulkrax::CsvParser"] = parser_mappings
Hyku.default_bulkrax_field_mappings = mappings
