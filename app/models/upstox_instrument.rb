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
end
