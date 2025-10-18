class UpstoxInstrument < Instrument
  def self.import_from_upstox(exchange: "NSE_MIS")
    upstox_api = Upstox::ApiService.new
    upstox_api.instruments(exchange: exchange)

    if upstox_api.response[:status] == "success"
      begin
        gzip_reader = Zlib::GzipReader.new(StringIO.new(upstox_api.response[:data].body))
        json_data = gzip_reader.read
        gzip_reader.close
      rescue StandardError => e
        raise "Failed to decompress instruments data: #{e.message}"
      end

      instruments_data = JSON.parse(json_data)
      imported_count = 0
      skipped_count = 0

      instruments_data.each do |data|
        instrument = UpstoxInstrument.find_or_initialize_by(
          identifier: data["instrument_key"]
        )
        instrument.symbol = data["trading_symbol"]
        instrument.name = data["name"]
        instrument.exchange = data["exchange"]
        instrument.segment = data["segment"]
        instrument.exchange_token = data["exchange_token"]
        instrument.tick_size = data["tick_size"].to_f
        instrument.lot_size = data["lot_size"].to_i
        instrument.raw_data = data

        if instrument.save
          MasterInstrument.create_from_exchange_data(
            instrument: instrument,
            exchange: instrument.exchange,
            exchange_token: instrument.exchange_token
          )
          imported_count += 1
        else
          skipped_count += 1
        end
      end

      { imported: imported_count, skipped: skipped_count, total: instruments_data.size }
    else
      raise "Failed to download instruments: #{upstox_api.response[:message]}"
    end
  end

  def create_instrument_history(unit: "day", interval: 1, from_date: 7.days.ago.to_date.to_s, to_date: Date.today.to_s)
    api_config = ApiConfiguration.upstox.last
    upstox_api = Upstox::ApiService.new(access_token: api_config.access_token)

    upstox_api.get_historical_candle_data(
      instrument: identifier,
      unit: unit.pluralize,
      interval: interval,
      to_date: to_date,
      from_date: from_date
    )

    candles = upstox_api.response&.dig("data", "candles")
    return unless candles

    candles.reverse.each do |candle_data|
      master_instrument.instrument_histories.find_or_initialize_by(
        unit: unit,
        interval: interval,
        date: candle_data[0]
      ).tap do |history|
        history.open = candle_data[1]
        history.high = candle_data[2]
        history.low = candle_data[3]
        history.close = candle_data[4]
        history.volume = candle_data[5]

        history.save!
      end
    end
  end
end
