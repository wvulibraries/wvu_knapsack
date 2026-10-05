# frozen_string_literal: true

# Configure dual logging (file + STDOUT) for both development and production.
# This initializer runs AFTER environment configuration, allowing us to override
# the logger setup from hyrax-webapp's config/environments/*.rb.
return unless ENV["RAILS_LOG_TO_STDOUT"].present?

# Use the actual log directory where the volume is mounted
logs_dir = Rails.root.join("log")
begin
  FileUtils.mkdir_p(logs_dir)
rescue Errno::EEXIST
  # Directory already exists as a mount point, which is fine
end

# DualIO wrapper writes to both file and STDOUT
class DualIO
  def initialize(file, stdout)
    @file = file
    @stdout = stdout
  end

  def write(msg)
    @file.write(msg)
    @stdout.write(msg)
  end

  def flush
    @file.flush
    @stdout.flush
  end

  def close
    # Keep handles open for the app lifecycle
  end
end

# Determine log filename based on Rails environment
log_filename = "#{Rails.env}.log"
log_path = logs_dir.join(log_filename)

# Open file for appending
file = File.open(log_path, "a")
file.sync = true

# # Create dual logger
# dual_io = DualIO.new(file, STDOUT)
# logger = ActiveSupport::Logger.new(dual_io)
# logger.formatter = Rails.application.config.log_formatter
# # Rails.logger = ActiveSupport::TaggedLogging.new(logger)
# Rails.logger = ActiveSupport::BroadcastLogger.new(ActiveSupport::TaggedLogging.new(logger))

dual_io = DualIO.new(file, STDOUT)
logger = ActiveSupport::Logger.new(dual_io)
logger.formatter = Rails.application.config.log_formatter

tagged_logger = ActiveSupport::TaggedLogging.new(logger)
broadcast_logger = ActiveSupport::BroadcastLogger.new(tagged_logger)

# BroadcastLogger's own #formatter doesn't automatically reflect what its broadcasts are
# using, so anything reading Rails.logger.formatter directly (ActiveJob's tag_logger check,
# among others) gets nil instead of the tag-aware formatter underneath — raising
# `undefined method 'current_tags' for nil` on every perform_later call. Set it explicitly
# so that top-level read is never nil.
broadcast_logger.formatter = tagged_logger.formatter

Rails.logger = broadcast_logger
