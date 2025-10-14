module Upstox
  class StopWebsocketConnectionJob < ApplicationJob
    queue_as :market_data

    def perform
      Rails.logger.info "[MarketData] Stopping market data service at #{Time.current}"

      redis_client.call("SET", "upstox:market_data:status", "stopping")

      30.times do
        status = redis_client.call("GET", "upstox:market_data:status")
        if status == "stopped"
          Rails.logger.info "[MarketData] Service stopped gracefully"
          cleanup_redis_keys
          return
        end

        sleep 1
      end

      Rails.logger.warn "[MarketData] Service did not stop gracefully, forcing cleanup"
      force_stop
      cleanup_redis_keys
    end

    private

    def redis_client
      @redis_client ||= RedisClient.config(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).new_client
    end

    def force_stop
      if defined?($market_data_service) && $market_data_service
        begin
          $market_data_service.disconnect
          $market_data_service = nil
          Rails.logger.info "[MarketData] Forced disconnection completed"
        rescue StandardError => e
          Rails.logger.error "[MarketData] Error during forced stop: #{e.message}"
        end
      end

      if EM.reactor_running?
        EM.stop
        Rails.logger.info "[MarketData] EventMachine reactor stopped"
      end

      redis_client.call("SET", "upstox:market_data:status", "stopped")
    end

    def cleanup_redis_keys
      redis_client.call("DEL", "upstox:market_data:status")
      Rails.logger.info "[MarketData] Redis keys cleaned up"
    end
  end
end
