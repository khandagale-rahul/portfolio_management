require 'rails_helper'

RSpec.describe ZerodhaInstrument, type: :model do
  it "inherits from Instrument" do
    expect(described_class.superclass).to eq(Instrument)
  end

  describe "constants" do
    it "defines LIST constant with supported exchanges" do
      expect(ZerodhaInstrument::LIST).to eq(%w[NSE])
    end
  end

  describe "STI behavior" do
    it "sets type to ZerodhaInstrument automatically" do
      instrument = create(:zerodha_instrument)
      expect(instrument.type).to eq("ZerodhaInstrument")
    end

    it "is queryable through Instrument.all" do
      zerodha = create(:zerodha_instrument)
      expect(Instrument.all).to include(zerodha)
    end

    it "is only queryable through ZerodhaInstrument" do
      upstox = create(:upstox_instrument)
      zerodha = create(:zerodha_instrument)

      zerodha_ids = ZerodhaInstrument.all.pluck(:id)
      expect(zerodha_ids).to include(zerodha.id)
      expect(zerodha_ids).not_to include(upstox.id)
    end
  end

  describe "attributes specific to Zerodha" do
    it "stores Zerodha-specific identifier format (instrument_token)" do
      instrument = create(:zerodha_instrument)
      expect(instrument.identifier).to match(/^\d+$/)
    end

    it "stores Zerodha segment" do
      instrument = create(:zerodha_instrument)
      expect(instrument.segment).to eq("NSE")
    end

    it "stores Zerodha-specific raw_data" do
      instrument = create(:zerodha_instrument)
      expect(instrument.raw_data).to have_key("instrument_token")
      expect(instrument.raw_data).to have_key("tradingsymbol")
      expect(instrument.raw_data).to have_key("instrument_type")
    end
  end

  describe ".import_instruments" do
    let(:mock_service) { instance_double(Zerodha::ApiService) }
    let(:api_key) { "test_api_key" }
    let(:access_token) { "test_access_token" }

    before do
      allow(Zerodha::ApiService).to receive(:new).and_return(mock_service)
    end

    context "when API call is successful" do
      let(:csv_data) do
        <<~CSV
          instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,exchange
          738561,2885,RELIANCE,Reliance Industries Ltd,2500.50,,0,0.05,1,EQ,NSE,NSE
          2953217,11536,TCS,Tata Consultancy Services Ltd,3500.75,,0,0.05,1,EQ,NSE,NSE
          5633,22,SBIN,State Bank of India,550.25,,0,0.05,1,EQ,NSE,NSE
          779521,3045,INFY,Infosys Ltd,1450.00,,0,0.05,1,EQ,BSE,BSE
        CSV
      end

      before do
        allow(mock_service).to receive(:instruments)
        allow(mock_service).to receive(:response).and_return({
          status: "success",
          data: csv_data
        })
      end

      it "imports only NSE exchange instruments" do
        expect {
          ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
        }.to change { ZerodhaInstrument.count }.by(3)
      end

      it "filters out non-NSE exchanges" do
        ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)

        infy = ZerodhaInstrument.find_by(symbol: "INFY")
        expect(infy).to be_nil
      end

      it "creates instruments with correct attributes" do
        ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)

        reliance = ZerodhaInstrument.find_by(symbol: "RELIANCE")
        expect(reliance).to be_present
        expect(reliance.name).to eq("Reliance Industries Ltd")
        expect(reliance.exchange).to eq("NSE")
        expect(reliance.identifier).to eq("738561")
        expect(reliance.exchange_token).to eq("2885")
        expect(reliance.segment).to eq("NSE")
      end

      it "stores complete CSV row data in raw_data" do
        ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)

        tcs = ZerodhaInstrument.find_by(symbol: "TCS")
        expect(tcs.raw_data["instrument_token"]).to eq("2953217")
        expect(tcs.raw_data["last_price"]).to eq("3500.75")
        expect(tcs.raw_data["instrument_type"]).to eq("EQ")
      end

      it "updates existing instruments instead of creating duplicates" do
        # First import
        ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)

        # Second import with same data
        expect {
          ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
        }.not_to change { ZerodhaInstrument.count }
      end

      it "uses identifier (instrument_token) for find_or_initialize" do
        ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)

        instrument = ZerodhaInstrument.find_by(identifier: "738561")
        expect(instrument).to be_present
        expect(instrument.symbol).to eq("RELIANCE")
      end

      it "only imports EQ (equity) instrument types" do
        csv_with_options = <<~CSV
          instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,exchange
          738561,2885,RELIANCE,Reliance Industries Ltd,2500.50,,0,0.05,1,EQ,NSE,NSE
          10396418,40611,RELIANCE25JAN2600CE,RELIANCE Jan 2025 2600 CE,50.00,2025-01-30,2600,0.05,250,CE,BFO,NSE
        CSV

        allow(mock_service).to receive(:response).and_return({
          status: "success",
          data: csv_with_options
        })

        expect {
          ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
        }.to change { ZerodhaInstrument.count }.by(1)

        # Only equity should be imported
        expect(ZerodhaInstrument.find_by(symbol: "RELIANCE")).to be_present
        expect(ZerodhaInstrument.find_by(symbol: "RELIANCE25JAN2600CE")).to be_nil
      end

      it "returns nil" do
        result = ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
        expect(result).to be_nil
      end

      it "calls Zerodha::ApiService with correct parameters" do
        expect(Zerodha::ApiService).to receive(:new).with(
          api_key: api_key,
          access_token: access_token
        ).and_return(mock_service)

        ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
      end
    end

    context "when API call fails" do
      before do
        allow(mock_service).to receive(:instruments)
        allow(mock_service).to receive(:response).and_return({
          status: "error",
          message: "Invalid access token"
        })
      end

      it "does not create any instruments" do
        expect {
          ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
        }.not_to change { ZerodhaInstrument.count }
      end

      it "returns nil" do
        result = ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
        expect(result).to be_nil
      end
    end

    context "with malformed CSV data" do
      let(:malformed_csv) { "not,valid,csv\ndata" }

      before do
        allow(mock_service).to receive(:instruments)
        allow(mock_service).to receive(:response).and_return({
          status: "success",
          data: malformed_csv
        })
      end

      it "handles CSV parsing gracefully" do
        expect {
          ZerodhaInstrument.import_instruments(api_key: api_key, access_token: access_token)
        }.not_to raise_error
      end
    end
  end

  describe "validations inherited from Instrument" do
    it "validates presence of required fields" do
      instrument = ZerodhaInstrument.new
      expect(instrument).not_to be_valid
      expect(instrument.errors).to have_key(:identifier)
      expect(instrument.errors).to have_key(:symbol)
      expect(instrument.errors).to have_key(:name)
    end

    it "validates uniqueness of identifier scoped to type" do
      create(:zerodha_instrument, identifier: "738561")
      duplicate = build(:zerodha_instrument, identifier: "738561")

      expect(duplicate).not_to be_valid
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:zerodha_instrument)).to be_valid
    end

    it "creates a valid ZerodhaInstrument" do
      instrument = create(:zerodha_instrument)
      expect(instrument).to be_persisted
      expect(instrument.type).to eq("ZerodhaInstrument")
    end
  end
end
