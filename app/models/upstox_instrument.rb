class UpstoxInstrument < Instrument
  def self.import_from_upstox(exchange: "NSE_MIS")
    require "net/http"
    require "zlib"
    require "json"

    url = URI("https://assets.upstox.com/market-quote/instruments/exchange/#{exchange}.json.gz")
    response = Net::HTTP.get_response(url)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Failed to download instruments: #{response.code} #{response.message}"
    end

    gzip_reader = Zlib::GzipReader.new(StringIO.new(response.body))
    json_data = gzip_reader.read
    gzip_reader.close

    instruments_data = JSON.parse(json_data)
    imported_count = 0
    skipped_count = 0

    instruments_data.each_with_index do |data, index|
      instrument = UpstoxInstrument.find_or_initialize_by(
        identifier: data["instrument_key"]
      )
      instrument.symbol = data["trading_symbol"],
      instrument.name = data["name"],
      instrument.exchange = data["exchange"],
      instrument.segment = data["segment"],
      instrument.tick_size = data["tick_size"].to_f,
      instrument.lot_size = data["lot_size"].to_i,
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
