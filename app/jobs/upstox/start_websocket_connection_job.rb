module Upstox
  class StartWebsocketConnectionJob < ApplicationJob
    include JobLogger

    queue_as :market_data

    def perform
      setup_job_logger
      log_info "[MarketData] Starting market data service at #{Time.current}"

      api_config = ApiConfiguration.where(api_name: :upstox)
                                    .find_by("oauth_authorized_at IS NOT NULL AND access_token IS NOT NULL")

      unless api_config
        log_error "[MarketData] No authorized Upstox API configuration found"
        redis_client.call("SET", "upstox:market_data:status", "error")
        redis_client.call("SET", "upstox:market_data:error_message", "No authorized API configuration found")
        return
      end

      if api_config.token_expired?
        log_error "[MarketData] Access token expired for API config #{api_config.id}"
        redis_client.call("SET", "upstox:market_data:status", "error")
        redis_client.call("SET", "upstox:market_data:error_message", "Access token expired")
        return
      end

      redis_client.call("SET", "upstox:market_data:status", "starting")

      Thread.new do
        begin
          service = Upstox::WebsocketService.new(api_config.access_token)

          service.on_message do |data|
            handle_market_data(data)
          end

          service.on_error do |error|
            log_error "[MarketData] WebSocket error: #{error}"
            redis_client.call("SET", "upstox:market_data:last_error", error.to_s)
            redis_client.call("SET", "upstox:market_data:last_error_time", Time.current.to_i.to_s)

            if error.to_s.include?("Max reconnection attempts")
              redis_client.call("SET", "upstox:market_data:status", "error")
              redis_client.call("SET", "upstox:market_data:error_message", error.to_s)
            end
          end

          service.on_connect do
            log_info "[MarketData] Connected successfully"
            redis_client.call("SET", "upstox:market_data:last_connected_at", Time.current.to_i.to_s)
            redis_client.call("SET", "upstox:market_data:reconnect_count", service.connection_stats[:reconnect_attempts].to_s)
          end

          service.on_disconnect do |code, reason|
            log_warn "[MarketData] Disconnected: code=#{code}, reason=#{reason}"
            redis_client.call("SET", "upstox:market_data:last_disconnected_at", Time.current.to_i.to_s)
          end

          $market_data_service = service

          EM.run do
            service.connect

            connection_timeout = EM.add_timer(30) do
              unless service.connected?
                log_error "[MarketData] Connection timeout - failed to connect within 30 seconds"
                redis_client.call("SET", "upstox:market_data:status", "error")
                redis_client.call("SET", "upstox:market_data:error_message", "Connection timeout")
                redis_client.call("SET", "upstox:market_data:error_time", Time.current.to_i.to_s)
              end
            end

            EM.add_timer(2) do
              if service.connected?
                subscribe_to_instruments(service)
                redis_client.call("SET", "upstox:market_data:status", "running")
                redis_client.call("DEL", "upstox:market_data:error_message")
                redis_client.call("DEL", "upstox:market_data:error_time")
                EM.cancel_timer(connection_timeout)
                log_info "[MarketData] Service running and subscribed to instruments"
              else
                log_warn "[MarketData] Service not connected yet, subscription deferred"
              end
            end

            EM.add_periodic_timer(60) do
              status = redis_client.call("GET", "upstox:market_data:status")
              if status == "stopping"
                log_info "[MarketData] Received stop signal, disconnecting..."
                service.disconnect
                EM.stop
              else
                stats = service.connection_stats
                log_info "[MarketData] Stats: connected=#{stats[:connected]}, " \
                                  "subscriptions=#{stats[:subscriptions_count]}, " \
                                  "reconnect_attempts=#{stats[:reconnect_attempts]}, " \
                                  "seconds_since_msg=#{stats[:seconds_since_last_message]}"

                redis_client.call("SET", "upstox:market_data:connection_stats", stats.to_json)
              end
            end
          end

          log_info "[MarketData] EventMachine reactor stopped"
          redis_client.call("SET", "upstox:market_data:status", "stopped")
          $market_data_service = nil
        rescue StandardError => e
          log_error "[MarketData] Error in market data service: #{e.message}"
          log_error e.backtrace.join("\n")
          redis_client.call("SET", "upstox:market_data:status", "error")
          redis_client.call("SET", "upstox:market_data:error_message", e.message)
          redis_client.call("SET", "upstox:market_data:error_time", Time.current.to_i.to_s)
          $market_data_service = nil
        end
      end

      log_info "[MarketData] Market data service thread started"
    end

    private

    def redis_client
      @redis_client ||= RedisClient.config(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).new_client
    end

    def handle_market_data(data)
      log_debug "[MarketData] Received data: #{data.inspect}"

      # Example: Broadcast to ActionCable (if you have a channel set up)
      # ActionCable.server.broadcast("market_data_channel", data)

      # Example: Store to database or process
      # MarketDataProcessor.process(data)
    end

    def subscribe_to_instruments(service)
      instruments = UpstoxInstrument.where(exchange: "NSE").pluck(:identifier)

      if instruments.any?
        service.subscribe(instruments, "ltpc")
        log_info "[MarketData] Subscribed to #{instruments.count} instruments"
      else
        log_warn "[MarketData] No instruments found to subscribe"
      end
    end
  end
end
