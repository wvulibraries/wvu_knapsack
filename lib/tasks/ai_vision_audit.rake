# frozen_string_literal: true

desc 'Audit AI remediation failures from the Rails log and report retry candidates'
namespace :hyku do
  namespace :ai do
    task :audit => :environment do
      # Failures are written to the standard Rails log tagged AI_REMEDIATION_FAILURE.
      # Grep the current environment log file for those entries.
      log_path = Rails.root.join('log', "#{Rails.env}.log")
      unless File.exist?(log_path)
        puts "No log file found at #{log_path}."
        next
      end

      failures = File.readlines(log_path).select { |l| l.include?('AI_REMEDIATION_FAILURE') }

      if failures.empty?
        puts 'No AI remediation failures found in the current log.'
        next
      end

      puts "AI Remediation Failures: #{failures.size} entries."
      puts ''
      failures.each { |line| puts line.strip }
      puts ''
      puts 'To re-enqueue all failed FileSets, run:'
      puts '  rake hyku:ai:reenqueue_failures'
    end

    task :reenqueue_failures => :environment do
      log_path = Rails.root.join('log', "#{Rails.env}.log")
      unless File.exist?(log_path)
        puts 'No log file found.'
        next
      end

      file_set_ids = File.readlines(log_path)
                         .select { |l| l.include?('AI_REMEDIATION_FAILURE') }
                         .filter_map { |l| l[/file_set_id=([^\s,]+)/, 1] }
                         .uniq

      if file_set_ids.empty?
        puts 'No failed FileSet IDs found in the log.'
        next
      end

      puts "Re-enqueuing #{file_set_ids.size} FileSet(s)..."
      file_set_ids.each do |id|
        fs = FileSet.find_by(id: id)
        unless fs
          puts "  WARN: FileSet #{id} not found — skipping."
          next
        end
        if fs.description.present?
          RemediateAltTextJob.perform_later(id)
        elsif fs.mime_type&.start_with?('image')
          AiDescriptionJob.perform_later(id)
        elsif fs.mime_type == 'application/pdf'
          # Re-enter the full PDF pipeline: OCR check first, then alt_text
          OcrPdfJob.perform_later(id)
        else
          puts "  SKIP: FileSet #{id} (#{fs.mime_type}) — no applicable remediation path."
          next
        end
        puts "  Enqueued FileSet #{id}"
      end
      puts 'Done.'
    end
  end
end
