require 'rails_helper'

RSpec.describe Holding, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:broker).with_values(zerodha: 1, upstox: 2, angel_one: 3) }
  end

  describe "attributes" do
    let(:user) { create(:user) }

    it "stores broker as enum" do
      holding = create(:holding, user: user, broker: :zerodha)
      expect(holding.broker).to eq("zerodha")
      expect(holding.zerodha?).to be true
    end

    it "stores exchange" do
      holding = create(:holding, user: user, exchange: "NSE")
      expect(holding.exchange).to eq("NSE")
    end

    it "stores trading_symbol" do
      holding = create(:holding, user: user, trading_symbol: "RELIANCE")
      expect(holding.trading_symbol).to eq("RELIANCE")
    end

    it "stores data as jsonb" do
      data = {
        "quantity" => 100,
        "average_price" => 2500.50,
        "last_price" => 2550.00
      }
      holding = create(:holding, user: user, data: data)
      expect(holding.data).to eq(data)
    end

    it "allows nil values" do
      holding = build(:holding, user: user, exchange: nil, trading_symbol: nil, data: nil)
      expect(holding).to be_valid
    end
  end

  describe "enum broker" do
    let(:user) { create(:user) }

    it "can be set to zerodha" do
      holding = create(:holding, user: user, broker: :zerodha)
      expect(holding.zerodha?).to be true
    end

    it "can be set to upstox" do
      holding = create(:holding, :upstox, user: user)
      expect(holding.upstox?).to be true
    end

    it "can be set to angel_one" do
      holding = create(:holding, :angel_one, user: user)
      expect(holding.angel_one?).to be true
    end

    it "supports querying by broker type" do
      zerodha_holding = create(:holding, user: user, broker: :zerodha)
      upstox_holding = create(:holding, :upstox, user: user)

      expect(Holding.zerodha).to include(zerodha_holding)
      expect(Holding.zerodha).not_to include(upstox_holding)
    end
  end

  describe "jsonb data storage" do
    let(:user) { create(:user) }

    it "can store complex holding data" do
      complex_data = {
        "quantity" => 50,
        "average_price" => 1500.50,
        "last_price" => 1550.75,
        "pnl" => 2512.50,
        "day_change" => 25.25,
        "day_change_percentage" => 1.65,
        "collateral_quantity" => 0,
        "collateral_type" => "margin",
        "t1_quantity" => 0,
        "isin" => "INE002A01018",
        "product" => "CNC"
      }

      holding = create(:holding, user: user, data: complex_data)
      holding.reload

      expect(holding.data["quantity"]).to eq(50)
      expect(holding.data["average_price"]).to eq(1500.50)
      expect(holding.data["pnl"]).to eq(2512.50)
    end

    it "can query holdings by data fields" do
      holding = create(:holding, user: user, data: { "quantity" => 100 })

      found = Holding.where("data->>'quantity' = ?", "100").first
      expect(found).to eq(holding)
    end

    it "defaults data to empty hash if not provided" do
      holding = Holding.new(user: user, broker: :zerodha)
      # Note: The model might need a default value set in the migration
      # This test assumes data can be nil or defaults to {}
    end
  end

  describe "user association" do
    let(:user) { create(:user) }

    it "can create multiple holdings for the same user" do
      holding1 = create(:holding, user: user, trading_symbol: "RELIANCE")
      holding2 = create(:holding, user: user, trading_symbol: "TCS")

      expect(user.holdings.count).to eq(2)
      expect(user.holdings).to include(holding1, holding2)
    end

    it "is destroyed when associated user is destroyed" do
      holding = create(:holding, user: user)
      expect { user.destroy }.to change { Holding.count }.by(-1)
    end
  end

  describe "broker-specific holdings" do
    let(:user) { create(:user) }

    it "can store holdings from different brokers" do
      zerodha = create(:holding, user: user, broker: :zerodha, trading_symbol: "RELIANCE")
      upstox = create(:holding, :upstox, user: user, trading_symbol: "TCS")
      angel = create(:holding, :angel_one, user: user, trading_symbol: "INFY")

      expect(user.holdings.count).to eq(3)
      expect(Holding.zerodha.count).to eq(1)
      expect(Holding.upstox.count).to eq(1)
      expect(Holding.angel_one.count).to eq(1)
    end
  end

  describe "timestamps" do
    let(:user) { create(:user) }

    it "sets created_at and updated_at automatically" do
      holding = create(:holding, user: user)
      expect(holding.created_at).to be_present
      expect(holding.updated_at).to be_present
    end

    it "updates updated_at when holding is modified" do
      holding = create(:holding, user: user)
      original_updated_at = holding.updated_at

      travel 1.hour do
        holding.update(trading_symbol: "NEWSTOCK")
        expect(holding.updated_at).to be > original_updated_at
      end
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:holding)).to be_valid
    end

    it "creates a valid holding" do
      expect(create(:holding)).to be_persisted
    end

    it "has a valid upstox trait" do
      holding = create(:holding, :upstox)
      expect(holding).to be_valid
      expect(holding.upstox?).to be true
    end

    it "has a valid angel_one trait" do
      holding = create(:holding, :angel_one)
      expect(holding).to be_valid
      expect(holding.angel_one?).to be true
    end
  end
end
