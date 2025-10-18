namespace :instrument_history do
  desc "Sync historical candle data for all Upstox instruments"
  task sync: :environment do
    puts "Starting Upstox instrument history sync..."
    puts "This may take a while depending on the number of instruments.\n\n"

    # Get user input for parameters or use defaults
    unit = ENV["UNIT"] || "day"
    interval = (ENV["INTERVAL"] || "1").to_i
    days_back = (ENV["DAYS_BACK"] || "7").to_i

    puts "Parameters:"
    puts "  Unit: #{unit} (valid: minute, hour, day, week, month)"
    puts "  Interval: #{interval}"
    puts "  Days back: #{days_back}"
    puts "\nYou can override these with: rake instrument_history:sync UNIT=day INTERVAL=1 DAYS_BACK=30"
    puts ""

    # Run the job
    Upstox::SyncInstrumentHistoryJob.perform_now(
      unit: unit,
      interval: interval,
      days_back: days_back
    )

    puts "\nSync completed. Check logs for details."
  end

  desc "Sync history for a specific instrument by symbol"
  task :sync_symbol, [:symbol] => :environment do |_t, args|
    symbol = args[:symbol] || ENV["SYMBOL"]

    unless symbol
      puts "Error: Please provide a symbol"
      puts "Usage: rake instrument_history:sync_symbol[RELIANCE]"
      puts "   or: rake instrument_history:sync_symbol SYMBOL=RELIANCE"
      exit 1
    end

    instrument = UpstoxInstrument.find_by(symbol: symbol)

    unless instrument
      puts "Error: Instrument with symbol '#{symbol}' not found"
      exit 1
    end

    puts "Syncing history for #{instrument.symbol} (#{instrument.name})..."

    unit = ENV["UNIT"] || "day"
    interval = (ENV["INTERVAL"] || "1").to_i
    days_back = (ENV["DAYS_BACK"] || "7").to_i

    from_date = days_back.days.ago.to_date.to_s
    to_date = Date.today.to_s

    begin
      instrument.create_instrument_history(
        unit: unit,
        interval: interval,
        from_date: from_date,
        to_date: to_date
      )
      puts "✓ Successfully synced #{instrument.symbol}"
    rescue StandardError => e
      puts "✗ Error syncing #{instrument.symbol}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "View sync statistics"
  task stats: :environment do
    puts "\n=== Instrument History Statistics ==="

    total_instruments = UpstoxInstrument.count
    instruments_with_history = UpstoxInstrument.joins(:master_instrument)
                                                .joins("INNER JOIN instrument_histories ON instrument_histories.master_instrument_id = master_instruments.id")
                                                .distinct.count

    total_records = InstrumentHistory.count
    latest_record = InstrumentHistory.order(date: :desc).first
    oldest_record = InstrumentHistory.order(date: :asc).first

    puts "\nInstruments:"
    puts "  Total Upstox instruments: #{total_instruments}"
    puts "  Instruments with history: #{instruments_with_history}"
    puts "  Coverage: #{instruments_with_history > 0 ? ((instruments_with_history.to_f / total_instruments * 100).round(2)) : 0}%"

    puts "\nHistory Records:"
    puts "  Total records: #{total_records}"

    if latest_record
      puts "  Latest date: #{latest_record.date.strftime('%Y-%m-%d')}"
    else
      puts "  Latest date: N/A"
    end

    if oldest_record
      puts "  Oldest date: #{oldest_record.date.strftime('%Y-%m-%d')}"
    else
      puts "  Oldest date: N/A"
    end

    # Count by unit
    puts "\nRecords by unit:"
    InstrumentHistory.group(:unit).count.each do |unit, count|
      puts "  #{unit || 'unknown'}: #{count}"
    end

    puts "=================================\n"
  end

  desc "View scheduled cron job status"
  task scheduled: :environment do
    puts "\n=== Scheduled Instrument History Sync Job ==="

    sync_job = Sidekiq::Cron::Job.find("sync_upstox_instrument_history")

    if sync_job
      puts "\nSync Job:"
      puts "  Name: #{sync_job.name}"
      puts "  Cron: #{sync_job.cron} (4:30 PM Monday-Friday)"
      puts "  Class: #{sync_job.klass}"
      puts "  Queue: #{sync_job.queue}"
      puts "  Description: #{sync_job.description}"
      puts "  Last enqueue: #{sync_job.last_enqueue_time || 'Never'}"
      puts "  Status: #{sync_job.status}"
    else
      puts "\nSync Job: Not configured"
      puts "Make sure Sidekiq-cron is loaded and schedule.yml is properly configured."
    end

    puts "=================================\n"
  end

  desc "Clear all instrument history data"
  task clear: :environment do
    print "Are you sure you want to delete ALL instrument history data? (yes/no): "
    confirmation = $stdin.gets.chomp

    if confirmation.downcase == "yes"
      count = InstrumentHistory.count
      InstrumentHistory.delete_all
      puts "✓ Deleted #{count} instrument history records"
    else
      puts "Cancelled"
    end
  end

  desc "Clear history for a specific instrument by symbol"
  task :clear_symbol, [:symbol] => :environment do |_t, args|
    symbol = args[:symbol] || ENV["SYMBOL"]

    unless symbol
      puts "Error: Please provide a symbol"
      puts "Usage: rake instrument_history:clear_symbol[RELIANCE]"
      exit 1
    end

    instrument = UpstoxInstrument.find_by(symbol: symbol)

    unless instrument
      puts "Error: Instrument with symbol '#{symbol}' not found"
      exit 1
    end

    if instrument.master_instrument
      count = instrument.master_instrument.instrument_histories.count
      instrument.master_instrument.instrument_histories.delete_all
      puts "✓ Deleted #{count} history records for #{instrument.symbol}"
    else
      puts "No history records found for #{instrument.symbol}"
    end
  end
end
