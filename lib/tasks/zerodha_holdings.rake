namespace :zerodha do
  desc "Sync holdings from Zerodha for all authorized users"
  task sync_holdings: :environment do
    puts "=" * 80
    puts "Zerodha Holdings Sync"
    puts "=" * 80
    puts ""

    # Use the sync holdings service
    service = Zerodha::SyncHoldingsService.new
    summary = service.sync_all

    if summary[:total_configs] == 0
      puts summary[:message]
      exit 0
    end

    puts "Found #{summary[:total_configs]} Zerodha API configuration(s)"
    puts ""

    # Display details for each result
    summary[:results].each do |result|
      puts "-" * 80
      puts "User: #{result[:user_name]} (#{result[:user_email]})"
      puts "API Config ID: #{result[:config_id]}"

      if result[:status] == :success
        puts "STATUS: SUCCESS"
        puts "Holdings synced: #{result[:holdings_synced]}"
        puts "Message: #{result[:message]}"
      else
        puts "STATUS: ERROR"
        puts "Message: #{result[:message]}"
      end

      puts ""
    end

    puts "=" * 80
    puts "Sync Summary"
    puts "=" * 80
    puts "Total configurations processed: #{summary[:total_configs]}"
    puts "Successful syncs: #{summary[:success_count]}"
    puts "Failed syncs: #{summary[:error_count]}"
    puts ""
    puts "Sync completed!"
  end
end
