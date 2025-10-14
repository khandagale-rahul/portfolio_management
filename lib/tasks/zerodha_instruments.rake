namespace :zerodha do
  desc "Import instruments from Zerodha Kite Connect API"
  task :import_instruments, [ :exchange, :config_id ] => :environment do |t, args|
    exchange = args[:exchange]
    config_id = args[:config_id]

    puts "=" * 80
    puts "Zerodha Instruments Import"
    puts "=" * 80

    api_config = if config_id.present?
      ApiConfiguration.zerodha.find_by(id: config_id)
    else
      ApiConfiguration.zerodha.first
    end

    unless api_config
      puts "ERROR: No Zerodha API configuration found."
      puts "Please create a Zerodha API configuration first or specify config_id."
      exit 1
    end

    unless api_config.oauth_authorized?
      puts "ERROR: Zerodha API configuration is not authorized."
      puts "Please authorize the API configuration through the web interface first."
      puts "Config ID: #{api_config.id}"
      puts "User: #{api_config.user.name} (#{api_config.user.email_address})"
      exit 1
    end

    if api_config.token_expired?
      puts "WARNING: Access token has expired. Please re-authorize."
      puts "Config ID: #{api_config.id}"
      exit 1
    end

    puts "Using API Configuration:"
    puts "  ID: #{api_config.id}"
    puts "  User: #{api_config.user.name} (#{api_config.user.email_address})"
    puts "  API Key: #{api_config.api_key[0..10]}..."
    puts "  Exchange: #{exchange || 'ALL'}"
    puts "  Token expires at: #{api_config.token_expires_at}"
    puts ""
    puts "Starting import..."
    puts ""

    start_time = Time.current

    result = ZerodhaInstrument.import_from_zerodha(
      exchange: exchange,
      api_key: api_config.api_key,
      access_token: api_config.access_token
    )

    end_time = Time.current
    duration = (end_time - start_time).round(2)

    puts ""
    puts "=" * 80
    puts "Import Results"
    puts "=" * 80

    if result[:error]
      puts "ERROR: #{result[:error]}"
      exit 1
    else
      puts "Total instruments: #{result[:total]}"
      puts "Imported: #{result[:imported]}"
      puts "Skipped: #{result[:skipped]}"
      puts "Duration: #{duration} seconds"
      puts ""
      puts "Import completed successfully!"
    end
  end

  desc "Show Zerodha instrument statistics"
  task instrument_stats: :environment do
    puts "=" * 80
    puts "Zerodha Instrument Statistics"
    puts "=" * 80
    puts ""

    total = ZerodhaInstrument.count
    puts "Total instruments: #{total}"

    if total > 0
      exchanges = ZerodhaInstrument.group(:exchange).count
      puts ""
      puts "By Exchange:"
      exchanges.sort.each do |exchange, count|
        puts "  #{exchange}: #{count}"
      end

      segments = ZerodhaInstrument.group(:segment).count
      puts ""
      puts "By Segment:"
      segments.sort.each do |segment, count|
        puts "  #{segment}: #{count}"
      end
    end
  end
end
