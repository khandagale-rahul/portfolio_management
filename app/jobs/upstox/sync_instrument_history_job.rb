module Upstox
  class SyncInstrumentHistoryJob < ApplicationJob
    queue_as :default

    # Sync historical candle data for all UpstoxInstruments
    # Options:
    #   unit: "day" (default), "minute", "hour", "week", "month"
    #   interval: 1 (default), depends on unit
    #   days_back: 7 (default) - number of days of history to fetch
    def perform(unit: "day", interval: 1, days_back: 7)
      Rails.logger.info "[InstrumentHistory] Starting instrument history sync at #{Time.current}"
      Rails.logger.info "[InstrumentHistory] Parameters: unit=#{unit}, interval=#{interval}, days_back=#{days_back}"

      # Check for authorized API configuration
      api_config = ApiConfiguration.where(api_name: :upstox)
                                    .find_by("oauth_authorized_at IS NOT NULL AND access_token IS NOT NULL")

      unless api_config
        Rails.logger.error "[InstrumentHistory] No authorized Upstox API configuration found"
        return
      end

      if api_config.token_expired?
        Rails.logger.error "[InstrumentHistory] Access token expired for API config #{api_config.id}"
        return
      end

      # Fetch all UpstoxInstruments
      instruments = UpstoxInstrument.all
      total_count = instruments.count
      success_count = 0
      error_count = 0

      Rails.logger.info "[InstrumentHistory] Found #{total_count} instruments to sync"

      from_date = days_back.days.ago.to_date.to_s
      to_date = Date.today.to_s

      instruments.find_each.with_index do |instrument, index|
        begin
          Rails.logger.info "[InstrumentHistory] Processing #{index + 1}/#{total_count}: #{instrument.symbol}"

          instrument.create_instrument_history(
            unit: unit,
            interval: interval,
            from_date: from_date,
            to_date: to_date
          )

          success_count += 1
          Rails.logger.info "[InstrumentHistory] Successfully synced #{instrument.symbol}"

          # Add a small delay to avoid rate limiting
          sleep(0.5) if (index + 1) % 10 == 0
        rescue StandardError => e
          error_count += 1
          Rails.logger.error "[InstrumentHistory] Error syncing #{instrument.symbol}: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
        end
      end

      Rails.logger.info "[InstrumentHistory] Sync completed at #{Time.current}"
      Rails.logger.info "[InstrumentHistory] Results: success=#{success_count}, errors=#{error_count}, total=#{total_count}"
    end
  end
end
