module Zerodha
  class SyncHoldingsJob < ApplicationJob
    queue_as :default

    def perform
      Rails.logger.info "[Zerodha] Starting holdings sync at #{Time.current}"

      # Use the sync holdings service
      service = Zerodha::SyncHoldingsService.new
      summary = service.sync_all

      if summary[:total_configs] == 0
        Rails.logger.warn "[Zerodha] #{summary[:message]}"
        return
      end

      Rails.logger.info "[Zerodha] Found #{summary[:total_configs]} Zerodha API configuration(s)"

      # Log details for each result
      summary[:results].each do |result|
        if result[:status] == :success
          Rails.logger.info "[Zerodha] SUCCESS: User #{result[:user_name]} (ID: #{result[:user_id]}) - #{result[:message]}"
        else
          Rails.logger.error "[Zerodha] ERROR: User #{result[:user_name]} (ID: #{result[:user_id]}) - #{result[:message]}"
        end
      end

      Rails.logger.info "[Zerodha] Holdings sync completed. Success: #{summary[:success_count]}, Errors: #{summary[:error_count]}"
    end
  end
end
