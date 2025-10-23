# frozen_string_literal: true

module JobLogger
  extend ActiveSupport::Concern

  included do
    attr_reader :job_logger
  end

  # Initialize a separate logger for this job
  def setup_job_logger
    log_dir = Rails.root.join("log", "jobs")
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)

    log_file = log_dir.join("#{logger_file_name}.log")

    @job_logger = Logger.new(log_file, "daily")
    @job_logger.level = Logger::INFO
    @job_logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
  end

  # Override this method in each job to specify the log file name
  def logger_file_name
    self.class.name.underscore.tr("/", "_")
  end

  # Convenience methods to log messages
  def log_info(message)
    job_logger.info(message)
  end

  def log_warn(message)
    job_logger.warn(message)
  end

  def log_error(message)
    job_logger.error(message)
  end

  def log_debug(message)
    job_logger.debug(message)
  end
end
