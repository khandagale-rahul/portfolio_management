namespace :market_data do
  desc "Start Upstox market data service manually"
  task start: :environment do
    puts "Starting Upstox market data service..."
    Upstox::StartWebsocketConnectionJob.perform_now
    puts "Market data service started. Check logs for details."
  end

  desc "Stop Upstox market data service manually"
  task stop: :environment do
    puts "Stopping Upstox market data service..."
    Upstox::StopWebsocketConnectionJob.perform_now
    puts "Market data service stopped."
  end

  desc "Check market data service status"
  task status: :environment do
    redis = RedisClient.config(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).new_client
    status = redis.call("GET", "upstox:market_data:status")
    last_connected = redis.call("GET", "upstox:market_data:last_connected_at")
    last_disconnected = redis.call("GET", "upstox:market_data:last_disconnected_at")
    reconnect_count = redis.call("GET", "upstox:market_data:reconnect_count")
    stats_json = redis.call("GET", "upstox:market_data:connection_stats")
    error_message = redis.call("GET", "upstox:market_data:error_message")
    error_time = redis.call("GET", "upstox:market_data:error_time")
    last_error = redis.call("GET", "upstox:market_data:last_error")
    last_error_time = redis.call("GET", "upstox:market_data:last_error_time")

    puts "\n=== Market Data Service Status ==="
    puts "Status: #{status || 'Not running'}"

    # Show error information if status is error
    if status == "error" && error_message
      puts "\n⚠️  ERROR DETAILS:"
      puts "Error: #{error_message}"
      if error_time
        time = Time.at(error_time.to_i)
        puts "Error time: #{time.strftime('%Y-%m-%d %H:%M:%S')} (#{time_ago(time)} ago)"
      end
    end

    puts "\n--- Connection Info ---"
    puts "Global service: #{defined?($market_data_service) && $market_data_service ? 'Active' : 'Inactive'}"
    puts "EventMachine reactor: #{EM.reactor_running? ? 'Running' : 'Stopped'}"

    if last_connected
      time = Time.at(last_connected.to_i)
      puts "Last connected: #{time.strftime('%Y-%m-%d %H:%M:%S')} (#{time_ago(time)} ago)"
    end

    if last_disconnected
      time = Time.at(last_disconnected.to_i)
      puts "Last disconnected: #{time.strftime('%Y-%m-%d %H:%M:%S')} (#{time_ago(time)} ago)"
    end

    puts "Reconnect count: #{reconnect_count || 0}"

    if stats_json
      stats = JSON.parse(stats_json, symbolize_names: true)
      puts "\n--- Live Stats ---"
      puts "Connected: #{stats[:connected]}"
      puts "Subscriptions: #{stats[:subscriptions_count]}"
      puts "Reconnect attempts: #{stats[:reconnect_attempts]}"
      puts "Seconds since last message: #{stats[:seconds_since_last_message] || 'N/A'}"
    end

    # Show last error if any (even if status is not error)
    if last_error && last_error_time
      puts "\n--- Last Error ---"
      puts "Error: #{last_error}"
      time = Time.at(last_error_time.to_i)
      puts "Time: #{time.strftime('%Y-%m-%d %H:%M:%S')} (#{time_ago(time)} ago)"
    end

    puts "================================\n"
  end

  desc "Run health check manually"
  task health_check: :environment do
    puts "Running health check..."
    Upstox::HealthCheckWebsocketConnectionJob.perform_now
    puts "Health check completed. Check logs for details."
  end

  desc "View scheduled cron jobs"
  task scheduled: :environment do
    puts "\n=== Scheduled Market Data Jobs ==="

    start_job = Sidekiq::Cron::Job.find("start_market_data")
    stop_job = Sidekiq::Cron::Job.find("stop_market_data")
    health_job = Sidekiq::Cron::Job.find("health_check_market_data")

    if start_job
      puts "\nStart Job:"
      puts "  Name: #{start_job.name}"
      puts "  Cron: #{start_job.cron}"
      puts "  Next run: #{start_job.last_enqueue_time}"
      puts "  Status: #{start_job.status}"
    else
      puts "\nStart Job: Not configured"
    end

    if stop_job
      puts "\nStop Job:"
      puts "  Name: #{stop_job.name}"
      puts "  Cron: #{stop_job.cron}"
      puts "  Next run: #{stop_job.last_enqueue_time}"
      puts "  Status: #{stop_job.status}"
    else
      puts "\nStop Job: Not configured"
    end

    if health_job
      puts "\nHealth Check Job:"
      puts "  Name: #{health_job.name}"
      puts "  Cron: #{health_job.cron}"
      puts "  Description: Runs every 5 minutes during trading hours"
      puts "  Next run: #{health_job.last_enqueue_time}"
      puts "  Status: #{health_job.status}"
    else
      puts "\nHealth Check Job: Not configured"
    end

    puts "=================================\n"
  end

  # Helper method for time_ago calculation
  def time_ago(time)
    seconds = (Time.current - time).to_i
    return "#{seconds}s" if seconds < 60

    minutes = seconds / 60
    return "#{minutes}m" if minutes < 60

    hours = minutes / 60
    return "#{hours}h" if hours < 24

    days = hours / 24
    "#{days}d"
  end
end
