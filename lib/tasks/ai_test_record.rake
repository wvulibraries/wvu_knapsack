# frozen_string_literal: true

desc 'Test AI alt text generation for a single work by Bulkrax source_identifier'
namespace :hyku do
  namespace :ai do
    task :test_record, [:idno] => :environment do |_t, args|
      idno = args[:idno]
      unless idno
        puts 'Usage: rake hyku:ai:test_record[identifier]'
        next
      end

      # Locate the work by Bulkrax source_identifier first, then plain identifier.
      work = ActiveFedora::Base.where(source_identifier_tesim: idno).first
      work ||= ActiveFedora::Base.where(identifier_tesim: idno).first
      unless work
        puts "No work found with identifier '#{idno}' (checked source_identifier_tesim and identifier_tesim)"
        next
      end

      file_set = work.file_sets.first
      unless file_set
        puts "No FileSet found for work '#{idno}'"
        next
      end

      puts "Work:    #{work.id}"
      puts "FileSet: #{file_set.id}"
      puts "MIME:    #{file_set.mime_type.inspect}"
      puts "Alt:     #{file_set.alt_text.inspect} (current)"
      puts ""

      description = file_set.description&.first.presence

      if description
        puts "Path: TEXT (description present) -> AltTextGeneratorService"
        result = AltTextGeneratorService.call(description)
      elsif file_set.mime_type&.start_with?('image')
        puts "Path: VISION (no description, is image) -> VisionService"
        result = VisionService.call(file_set)
      elsif file_set.mime_type == 'application/pdf'
        puts "Path: PDF -> PdfAccessibilityService (pdftotext first, pdftoppm+VisionService fallback)"
        result = PdfAccessibilityService.call(file_set)
      else
        puts "Path: NONE — no description and unsupported MIME (#{file_set.mime_type}). No AI action would be taken."
        next
      end

      if result.present?
        puts "Result (#{result.length} chars): #{result.inspect}"
      else
        puts "Result: nil — Ollama returned no usable output."
      end
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      Rails.logger.tagged('AI_REMEDIATION_FAILURE') { Rails.logger.error("[test_record] #{e.class} for FileSet #{file_set&.id}: #{e.message}") }
      puts "Connection error: #{e.class}: #{e.message} (logged to Rails log with AI_REMEDIATION_FAILURE tag)"
    end
  end
end
