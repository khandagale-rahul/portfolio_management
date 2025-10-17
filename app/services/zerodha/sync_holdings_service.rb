module Zerodha
  class SyncHoldingsService
    attr_reader :success_count, :error_count, :results

    def initialize
      @success_count = 0
      @error_count = 0
      @results = []
    end

    def sync_all
      api_configs = ApiConfiguration.zerodha.where.not(access_token: nil)

      if api_configs.empty?
        return {
          success: true,
          message: "No authorized Zerodha API configurations found",
          total_configs: 0,
          success_count: 0,
          error_count: 0,
          results: []
        }
      end

      api_configs.each do |api_config|
        sync_for_config(api_config)
      end

      {
        success: true,
        total_configs: api_configs.count,
        success_count: @success_count,
        error_count: @error_count,
        results: @results
      }
    end

    def sync_for_config(api_config)
      result = {
        user_id: api_config.user.id,
        user_name: api_config.user.name,
        user_email: api_config.user.email_address,
        config_id: api_config.id,
        status: nil,
        message: nil,
        holdings_synced: 0
      }

      if api_config.token_expired?
        result[:status] = :error
        result[:message] = "Access token expired"
        @error_count += 1
        @results << result
        return result
      end

      begin
        api_service = Zerodha::ApiService.new(
          api_key: api_config.api_key,
          access_token: api_config.access_token
        )

        api_service.get_holdings

        if api_service.response["status"] == "success"
          all_holdings_data = api_service.response["data"]
          holdings_synced = 0

          all_holdings_data.each do |holdings_data|
            holding = api_config.user.holdings.find_or_initialize_by(
              broker: :zerodha,
              exchange: holdings_data["exchange"],
              trading_symbol: holdings_data["tradingsymbol"]
            )

            holding.data = holdings_data

            if holding.save
              holdings_synced += 1
            else
              result[:message] = "Some holdings failed to save: #{holding.errors.full_messages.join(', ')}"
            end
          end

          result[:status] = :success
          result[:holdings_synced] = holdings_synced
          result[:message] ||= "Successfully synced #{holdings_synced} holdings"
          @success_count += 1
        else
          result[:status] = :error
          result[:message] = "API call failed: #{api_service.response['message']}"
          @error_count += 1
        end
      rescue => e
        result[:status] = :error
        result[:message] = "Exception: #{e.message}"
        @error_count += 1
      end

      @results << result
      result
    end
  end
end
