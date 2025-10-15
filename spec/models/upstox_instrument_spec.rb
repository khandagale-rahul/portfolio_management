require 'rails_helper'

RSpec.describe UpstoxInstrument, type: :model do
  it "inherits from Instrument" do
    expect(described_class.superclass).to eq(Instrument)
  end

  describe "STI behavior" do
    it "sets type to UpstoxInstrument automatically" do
      instrument = create(:upstox_instrument)
      expect(instrument.type).to eq("UpstoxInstrument")
    end

    it "is queryable through Instrument.all" do
      upstox = create(:upstox_instrument)
      expect(Instrument.all).to include(upstox)
    end

    it "is only queryable through UpstoxInstrument" do
      upstox = create(:upstox_instrument)
      zerodha = create(:zerodha_instrument)

      upstox_ids = UpstoxInstrument.all.pluck(:id)
      expect(upstox_ids).to include(upstox.id)
      expect(upstox_ids).not_to include(zerodha.id)
    end
  end

  describe "attributes specific to Upstox" do
    it "stores Upstox-specific identifier format" do
      instrument = create(:upstox_instrument)
      expect(instrument.identifier).to match(/NSE_EQ\|INE\d+/)
    end

    it "stores Upstox segment NSE_MIS" do
      instrument = create(:upstox_instrument)
      expect(instrument.segment).to eq("NSE_MIS")
    end

    it "stores Upstox-specific raw_data" do
      instrument = create(:upstox_instrument)
      expect(instrument.raw_data).to have_key("instrument_key")
      expect(instrument.raw_data).to have_key("trading_symbol")
    end
  end

  describe ".import_from_upstox" do
    let(:mock_service) { instance_double(Upstox::ApiService) }

    before do
      allow(Upstox::ApiService).to receive(:new).and_return(mock_service)
    end

    context "when API call is successful" do
      let(:gzip_data) do
        json_data = [
          {
            "instrument_key" => "NSE_EQ|INE002A01018",
            "exchange_token" => "2885",
            "trading_symbol" => "RELIANCE",
            "name" => "Reliance Industries Ltd",
            "exchange" => "NSE",
            "segment" => "NSE_MIS",
            "tick_size" => 0.05,
            "lot_size" => 1
          },
          {
            "instrument_key" => "NSE_EQ|INE467B01029",
            "exchange_token" => "11536",
            "trading_symbol" => "TCS",
            "name" => "Tata Consultancy Services",
            "exchange" => "NSE",
            "segment" => "NSE_MIS",
            "tick_size" => 0.05,
            "lot_size" => 1
          }
        ].to_json

        # Create gzipped data
        io = StringIO.new
        gz = Zlib::GzipWriter.new(io)
        gz.write(json_data)
        gz.close
        io.string
      end

      let(:mock_response) do
        response_double = double('Response')
        allow(response_double).to receive(:body).and_return(gzip_data)
        response_double
      end

      before do
        allow(mock_service).to receive(:instruments)
        allow(mock_service).to receive(:response).and_return({
          status: "success",
          data: mock_response
        })
      end

      it "imports instruments from Upstox API" do
        expect {
          UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")
        }.to change { UpstoxInstrument.count }.by(2)
      end

      it "creates instruments with correct attributes" do
        UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")

        reliance = UpstoxInstrument.find_by(symbol: "RELIANCE")
        expect(reliance).to be_present
        expect(reliance.name).to eq("Reliance Industries Ltd")
        expect(reliance.exchange).to eq("NSE")
        expect(reliance.identifier).to eq("NSE_EQ|INE002A01018")
        expect(reliance.exchange_token).to eq("2885")
      end

      it "returns import statistics" do
        result = UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")

        expect(result[:imported]).to eq(2)
        expect(result[:skipped]).to eq(0)
        expect(result[:total]).to eq(2)
      end

      it "updates existing instruments instead of creating duplicates" do
        # First import
        UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")

        # Second import with same data
        expect {
          UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")
        }.not_to change { UpstoxInstrument.count }
      end

      it "uses identifier (instrument_key) for find_or_initialize" do
        result = UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")

        instrument = UpstoxInstrument.find_by(identifier: "NSE_EQ|INE002A01018")
        expect(instrument).to be_present
      end
    end

    context "when API call fails" do
      before do
        allow(mock_service).to receive(:instruments)
        allow(mock_service).to receive(:response).and_return({
          status: "error",
          message: "API request failed"
        })
      end

      it "raises an error with the failure message" do
        expect {
          UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")
        }.to raise_error("Failed to download instruments: API request failed")
      end
    end

    context "when gzip decompression fails" do
      let(:invalid_gzip_data) { "invalid gzip data" }
      let(:mock_response) do
        response_double = double('Response')
        allow(response_double).to receive(:body).and_return(invalid_gzip_data)
        response_double
      end

      before do
        allow(mock_service).to receive(:instruments)
        allow(mock_service).to receive(:response).and_return({
          status: "success",
          data: mock_response
        })
      end

      it "raises an error" do
        expect {
          UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")
        }.to raise_error(/Failed to decompress instruments data/)
      end
    end
  end

  describe "validations inherited from Instrument" do
    it "validates presence of required fields" do
      instrument = UpstoxInstrument.new
      expect(instrument).not_to be_valid
      expect(instrument.errors).to have_key(:identifier)
      expect(instrument.errors).to have_key(:symbol)
      expect(instrument.errors).to have_key(:name)
    end

    it "validates uniqueness of identifier scoped to type" do
      create(:upstox_instrument, identifier: "NSE_EQ|INE123456")
      duplicate = build(:upstox_instrument, identifier: "NSE_EQ|INE123456")

      expect(duplicate).not_to be_valid
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:upstox_instrument)).to be_valid
    end

    it "creates a valid UpstoxInstrument" do
      instrument = create(:upstox_instrument)
      expect(instrument).to be_persisted
      expect(instrument.type).to eq("UpstoxInstrument")
    end
  end
end
