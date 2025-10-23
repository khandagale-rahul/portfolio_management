module Zerodha
  class SyncHoldingsJob < ApplicationJob
    include JobLogger

    queue_as :default

    def perform
      setup_job_logger
      log_info "[Zerodha] Starting holdings sync at #{Time.current}"

      # Use the sync holdings service
      service = Zerodha::SyncHoldingsService.new
      summary = service.sync_all

      if summary[:total_configs] == 0
        log_warn "[Zerodha] #{summary[:message]}"
        return
      end

      log_info "[Zerodha] Found #{summary[:total_configs]} Zerodha API configuration(s)"

      # Log details for each result
      summary[:results].each do |result|
        if result[:status] == :success
          log_info "[Zerodha] SUCCESS: User #{result[:user_name]} (ID: #{result[:user_id]}) - #{result[:message]}"
        else
          log_error "[Zerodha] ERROR: User #{result[:user_name]} (ID: #{result[:user_id]}) - #{result[:message]}"
        end
      end

      log_info "[Zerodha] Holdings sync completed. Success: #{summary[:success_count]}, Errors: #{summary[:error_count]}"
    end
  end
end
