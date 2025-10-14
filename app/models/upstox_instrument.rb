class UpstoxInstrument < Instrument
  def self.import_from_upstox(exchange: "NSE_MIS")
    url = "https://assets.upstox.com/market-quote/instruments/exchange/#{exchange}.json.gz"

    begin
      response = RestClient::Request.execute(
        method: :get,
        url: url,
        timeout: 40
      )

      gzip_reader = Zlib::GzipReader.new(StringIO.new(response.body))
      json_data = gzip_reader.read
      gzip_reader.close
    rescue RestClient::ExceptionWithResponse => e
      raise "Failed to download instruments: #{e.http_code} #{e.message}"
    rescue StandardError => e
      raise "Failed to download instruments: #{e.message}"
    end

    instruments_data = JSON.parse(json_data)
    imported_count = 0
    skipped_count = 0

    instruments_data.each_with_index do |data, index|
      instrument = UpstoxInstrument.find_or_initialize_by(
        identifier: data["instrument_key"]
      )
      instrument.symbol = data["trading_symbol"]
      instrument.name = data["name"]
      instrument.exchange = data["exchange"]
      instrument.segment = data["segment"]
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
  end
end
