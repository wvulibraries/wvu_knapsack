# OVERRIDE: Dual logging for development environment (GitHub #8)
# The app runs in RAILS_ENV=development locally, so production.rb is never loaded.
# This initializer ensures dual logging (file + STDOUT) works in development mode too.

Rails.application.config.after_initialize do |app|
  next unless ENV["RAILS_LOG_TO_STDOUT"].present?

  # Use shared data/logs/rails directory for consistency with production
  # Note: Rails.root = /app/samvera/hyrax-webapp, so parent gets us to /app/samvera
  logs_dir = Rails.root.parent.join("data", "logs", "rails")
  logs_dir.mkpath unless logs_dir.exist?
  log_path = logs_dir.join("development.log")
  
  # Create file logger
  file_logger = ActiveSupport::Logger.new(log_path)
  file_logger.formatter = app.config.log_formatter || ::Logger::Formatter.new
  
  # Create STDOUT logger
  stdout_logger = ActiveSupport::Logger.new(STDOUT)
  stdout_logger.formatter = app.config.log_formatter || ::Logger::Formatter.new
  
  # Create a dual logger that writes to both destinations
  dual_io = Object.new
  
  # Define logging methods that write to both file and STDOUT
  def dual_io.debug(msg)
    @file_logger.debug(msg)
    @stdout_logger.debug(msg)
  end
  
  def dual_io.info(msg)
    @file_logger.info(msg)
    @stdout_logger.info(msg)
  end
  
  def dual_io.warn(msg)
    @file_logger.warn(msg)
    @stdout_logger.warn(msg)
  end
  
  def dual_io.error(msg)
    @file_logger.error(msg)
    @stdout_logger.error(msg)
  end
  
  def dual_io.fatal(msg)
    @file_logger.fatal(msg)
    @stdout_logger.fatal(msg)
  end
  
  def dual_io.unknown(msg)
    @file_logger.unknown(msg)
    @stdout_logger.unknown(msg)
  end
  
  def dual_io.formatter
    @file_logger.formatter
  end
  
  def dual_io.formatter=(fmt)
    @file_logger.formatter = fmt
    @stdout_logger.formatter = fmt
  end
  
  # Attach the loggers to the object
  dual_io.instance_variable_set(:@file_logger, file_logger)
  dual_io.instance_variable_set(:@stdout_logger, stdout_logger)
  
  app.config.logger = ActiveSupport::TaggedLogging.new(dual_io)
end
