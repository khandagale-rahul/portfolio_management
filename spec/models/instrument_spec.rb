require 'rails_helper'

RSpec.describe Instrument, type: :model do
  describe "associations" do
    it "has_one upstox_instrument association" do
      expect(described_class.reflect_on_association(:upstox_instrument)).to be_present
      expect(described_class.reflect_on_association(:upstox_instrument).macro).to eq(:has_one)
    end

    it "has_one zerodha_instrument association" do
      expect(described_class.reflect_on_association(:zerodha_instrument)).to be_present
      expect(described_class.reflect_on_association(:zerodha_instrument).macro).to eq(:has_one)
    end
  end

  describe "validations" do
    subject { build(:instrument) }

    context "presence validations" do
      it { is_expected.to validate_presence_of(:symbol) }
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:exchange) }
      it { is_expected.to validate_presence_of(:segment) }
      it { is_expected.to validate_presence_of(:identifier) }
      it { is_expected.to validate_presence_of(:exchange_token) }
      it { is_expected.to validate_presence_of(:tick_size) }
      it { is_expected.to validate_presence_of(:lot_size) }
    end

    context "uniqueness validations" do
      it "validates uniqueness of identifier scoped to type" do
        create(:instrument, identifier: "TEST123", type: "Instrument")
        duplicate = build(:instrument, identifier: "TEST123", type: "Instrument")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include("has already been taken")
      end

      it "allows same identifier for different types" do
        create(:upstox_instrument, identifier: "TEST123")
        different_type = build(:zerodha_instrument, identifier: "TEST123")

        expect(different_type).to be_valid
      end
    end
  end

  describe "attributes" do
    let(:instrument) { create(:instrument) }

    it "stores symbol" do
      expect(instrument.symbol).to be_present
    end

    it "stores name" do
      expect(instrument.name).to be_present
    end

    it "stores exchange" do
      expect(instrument.exchange).to eq("NSE")
    end

    it "stores segment" do
      expect(instrument.segment).to be_present
    end

    it "stores identifier" do
      expect(instrument.identifier).to be_present
    end

    it "stores exchange_token" do
      expect(instrument.exchange_token).to be_present
    end

    it "stores tick_size as decimal" do
      expect(instrument.tick_size).to be_a(BigDecimal)
      expect(instrument.tick_size).to eq(0.05)
    end

    it "stores lot_size as integer" do
      expect(instrument.lot_size).to be_an(Integer)
      expect(instrument.lot_size).to eq(1)
    end

    it "stores raw_data as jsonb" do
      instrument = create(:instrument, raw_data: { "test_key" => "test_value" })
      expect(instrument.raw_data).to eq({ "test_key" => "test_value" })
    end

    it "defaults raw_data to empty hash" do
      instrument = Instrument.new
      expect(instrument.raw_data).to eq({})
    end
  end

  describe "#display_name" do
    it "returns formatted display name" do
      instrument = build(:instrument,
        symbol: "RELIANCE",
        name: "Reliance Industries Ltd",
        exchange: "NSE"
      )

      expect(instrument.display_name).to eq("RELIANCE - Reliance Industries Ltd (NSE)")
    end

    it "handles different combinations of symbol, name, and exchange" do
      instrument = build(:instrument,
        symbol: "TCS",
        name: "Tata Consultancy Services",
        exchange: "BSE"
      )

      expect(instrument.display_name).to eq("TCS - Tata Consultancy Services (BSE)")
    end
  end

  describe "Single Table Inheritance (STI)" do
    it "creates base Instrument type" do
      instrument = create(:instrument, type: "Instrument")
      expect(instrument.type).to eq("Instrument")
      expect(instrument).to be_an(Instrument)
    end

    it "creates UpstoxInstrument type" do
      instrument = create(:upstox_instrument)
      expect(instrument.type).to eq("UpstoxInstrument")
      expect(instrument).to be_a(UpstoxInstrument)
      expect(instrument).to be_a(Instrument)
    end

    it "creates ZerodhaInstrument type" do
      instrument = create(:zerodha_instrument)
      expect(instrument.type).to eq("ZerodhaInstrument")
      expect(instrument).to be_a(ZerodhaInstrument)
      expect(instrument).to be_a(Instrument)
    end

    it "queries all instruments regardless of type" do
      create(:instrument)
      create(:upstox_instrument)
      create(:zerodha_instrument)

      expect(Instrument.count).to eq(3)
    end

    it "queries only UpstoxInstruments" do
      create(:instrument)
      upstox = create(:upstox_instrument)
      create(:zerodha_instrument)

      expect(UpstoxInstrument.count).to eq(1)
      expect(UpstoxInstrument.first.id).to eq(upstox.id)
    end

    it "queries only ZerodhaInstruments" do
      create(:instrument)
      create(:upstox_instrument)
      zerodha = create(:zerodha_instrument)

      expect(ZerodhaInstrument.count).to eq(1)
      expect(ZerodhaInstrument.first.id).to eq(zerodha.id)
    end
  end

  describe "raw_data JSONB queries" do
    it "can query instruments by raw_data fields" do
      instrument = create(:instrument, raw_data: { "last_price" => "1500.50" })

      found = Instrument.where("raw_data->>'last_price' = ?", "1500.50").first
      expect(found.id).to eq(instrument.id)
    end

    it "can store and retrieve complex JSON data" do
      complex_data = {
        "market_data" => {
          "open" => 1500.00,
          "high" => 1550.00,
          "low" => 1490.00,
          "close" => 1530.00
        },
        "volume" => 1_000_000
      }

      instrument = create(:instrument, raw_data: complex_data)
      instrument.reload

      expect(instrument.raw_data).to eq(complex_data)
      expect(instrument.raw_data["market_data"]["high"]).to eq(1550.00)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:instrument)).to be_valid
    end

    it "creates a valid instrument" do
      expect(create(:instrument)).to be_persisted
    end

    it "has a valid upstox_instrument factory" do
      instrument = create(:upstox_instrument)
      expect(instrument).to be_valid
      expect(instrument.type).to eq("UpstoxInstrument")
    end

    it "has a valid zerodha_instrument factory" do
      instrument = create(:zerodha_instrument)
      expect(instrument).to be_valid
      expect(instrument.type).to eq("ZerodhaInstrument")
    end
  end
end
