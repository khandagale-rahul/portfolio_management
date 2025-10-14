module Upstox
  class HealthCheckWebsocketConnectionJob < ApplicationJob
    queue_as :market_data

    def perform
      current_time = Time.current

      return unless trading_hours?(current_time)

      Rails.logger.info "[MarketData] Health check running at #{current_time}"

      status = redis_client.call("GET", "upstox:market_data:status")

      if should_be_running?(status)
        Rails.logger.warn "[MarketData] Service should be running but status is '#{status}'. Restarting..."
        restart_service
      else
        if status == "running"
          check_service_health
        else
          Rails.logger.info "[MarketData] Service status: #{status || 'not started'}"
        end
      end
    end

    private

    def redis_client
      @redis_client ||= RedisClient.config(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).new_client
    end

    def trading_hours?(time)
      return false unless (1..5).include?(time.wday)

      start_time = time.change(hour: 9, min: 0)
      end_time = time.change(hour: 15, min: 30)

      time >= start_time && time <= end_time
    end

    def should_be_running?(status)
      status.nil? || status == "stopped" || status == "error"
    end

    def restart_service
      Rails.logger.info "[MarketData] Attempting to restart service..."

      Upstox::StartWebsocketConnectionJob.perform_now

      sleep 5

      new_status = redis_client.call("GET", "upstox:market_data:status")
      if new_status == "running" || new_status == "starting"
        Rails.logger.info "[MarketData] Service restarted successfully. Status: #{new_status}"
      else
        Rails.logger.error "[MarketData] Service restart failed. Status: #{new_status}"
      end
    end

    def check_service_health
      unless defined?($market_data_service) && $market_data_service
        Rails.logger.warn "[MarketData] Status is 'running' but service instance not found. Restarting..."
        restart_service
        return
      end

      unless $market_data_service.connected?
        Rails.logger.warn "[MarketData] Service instance exists but not connected. Connection may be recovering..."

        stats_json = redis_client.call("GET", "upstox:market_data:connection_stats")
        if stats_json
          stats = JSON.parse(stats_json, symbolize_names: true)
          reconnect_attempts = stats[:reconnect_attempts] || 0

          if reconnect_attempts >= 5
            Rails.logger.error "[MarketData] Service has #{reconnect_attempts} reconnect attempts. Forcing restart..."
            restart_service
          else
            Rails.logger.info "[MarketData] Service attempting reconnection (#{reconnect_attempts} attempts). Waiting..."
          end
        end
        return
      end

      stats = $market_data_service.connection_stats
      seconds_since_last_msg = stats[:seconds_since_last_message]

      if seconds_since_last_msg && seconds_since_last_msg > 300
        Rails.logger.error "[MarketData] No messages received for #{seconds_since_last_msg} seconds. Service may be stuck. Restarting..."
        restart_service
      else
        Rails.logger.info "[MarketData] Service is healthy. Last message: #{seconds_since_last_msg}s ago"
      end
    end
  end
end
