# frozen_string_literal: true

# Configure dual logging (file + STDOUT) for both development and production.
# This initializer runs AFTER environment configuration, allowing us to override
# the logger setup from hyrax-webapp's config/environments/*.rb.
return unless ENV["RAILS_LOG_TO_STDOUT"].present?

logs_dir = Rails.root.parent.join("data", "logs", "rails")
FileUtils.mkdir_p(logs_dir)

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

# Create dual logger
dual_io = DualIO.new(file, STDOUT)
logger = ActiveSupport::Logger.new(dual_io)
logger.formatter = Rails.application.config.log_formatter
Rails.logger = ActiveSupport::TaggedLogging.new(logger)
