# frozen_string_literal: true

# WVU Knapsack Development Environment Configuration
# This file is loaded AFTER hyrax-webapp's config/environments/development.rb
# and can override/extend those settings for Knapsack-specific customizations.

Rails.application.configure do
  # Dual logging to file + STDOUT for development
  # Ensures logs persist to disk while maintaining Docker container visibility
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    # Create logs directory if it doesn't exist
    logs_dir = Rails.root.parent.join("data", "logs", "rails")
    FileUtils.mkdir_p(logs_dir)

    file = File.open(logs_dir.join("development.log"), "a")
    file.sync = true

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

    dual_io = DualIO.new(file, STDOUT)
    logger = ActiveSupport::Logger.new(dual_io)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end
end
