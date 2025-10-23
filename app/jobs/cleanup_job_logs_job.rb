# frozen_string_literal: true

class CleanupJobLogsJob < ApplicationJob
  queue_as :default

  def perform(days: 7)
    # Simply invoke the rake task
    Rake::Task["job_logs:cleanup"].reenable
    Rake::Task["job_logs:cleanup"].invoke(days)
  end
end
