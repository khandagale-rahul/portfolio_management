require 'rails_helper'

RSpec.describe ApiConfiguration, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:api_name).with_values(zerodha: 1, upstox: 2, angel_one: 3) }
  end

  describe "validations" do
    subject { build(:api_configuration) }

    context "presence validations" do
      it { is_expected.to validate_presence_of(:api_name) }
      it { is_expected.to validate_presence_of(:api_key) }
      it { is_expected.to validate_presence_of(:api_secret) }
    end

    context "uniqueness validations" do
      it "validates uniqueness of api_name scoped to user_id" do
        user = create(:user)
        create(:api_configuration, user: user, api_name: :zerodha)
        duplicate = build(:api_configuration, user: user, api_name: :zerodha)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:api_name]).to include("has already been taken")
      end

      it "allows same api_name for different users" do
        user1 = create(:user)
        user2 = create(:user)
        create(:api_configuration, user: user1, api_name: :zerodha)
        second_config = build(:api_configuration, user: user2, api_name: :zerodha)

        expect(second_config).to be_valid
      end

      it "allows different api_names for the same user" do
        user = create(:user)
        create(:api_configuration, user: user, api_name: :zerodha)
        second_config = build(:api_configuration, user: user, api_name: :upstox)

        expect(second_config).to be_valid
      end
    end
  end

  describe "#oauth_authorized?" do
    it "returns true when oauth_authorized_at and access_token are present" do
      config = build(:api_configuration, :authorized)
      expect(config.oauth_authorized?).to be true
    end

    it "returns false when oauth_authorized_at is nil" do
      config = build(:api_configuration, oauth_authorized_at: nil, access_token: "token123")
      expect(config.oauth_authorized?).to be false
    end

    it "returns false when access_token is nil" do
      config = build(:api_configuration, oauth_authorized_at: Time.current, access_token: nil)
      expect(config.oauth_authorized?).to be false
    end

    it "returns false when both are nil" do
      config = build(:api_configuration)
      expect(config.oauth_authorized?).to be false
    end
  end

  describe "#token_expired?" do
    it "returns true when token_expires_at is blank" do
      config = build(:api_configuration, token_expires_at: nil)
      expect(config.token_expired?).to be true
    end

    it "returns true when token_expires_at is in the past" do
      config = build(:api_configuration, token_expires_at: 1.day.ago)
      expect(config.token_expired?).to be true
    end

    it "returns false when token_expires_at is in the future" do
      config = build(:api_configuration, token_expires_at: 1.day.from_now)
      expect(config.token_expired?).to be false
    end

    it "returns false when token_expires_at is current time" do
      current_time = Time.current
      config = build(:api_configuration, token_expires_at: current_time)

      # Freeze time to ensure accurate comparison
      travel_to(current_time - 1.second) do
        expect(config.token_expired?).to be false
      end
    end
  end

  describe "#requires_reauthorization?" do
    it "returns true when not oauth authorized" do
      config = build(:api_configuration)
      expect(config.requires_reauthorization?).to be true
    end

    it "returns true when token is expired" do
      config = build(:api_configuration, :expired_token)
      expect(config.requires_reauthorization?).to be true
    end

    it "returns false when authorized and token is valid" do
      config = build(:api_configuration, :authorized)
      expect(config.requires_reauthorization?).to be false
    end
  end

  describe "#oauth_status" do
    it 'returns "Not Authorized" when not authorized' do
      config = build(:api_configuration)
      expect(config.oauth_status).to eq("Not Authorized")
    end

    it 'returns "Token Expired" when token is expired' do
      config = build(:api_configuration, :expired_token)
      expect(config.oauth_status).to eq("Token Expired")
    end

    it 'returns "Authorized" when authorized with valid token' do
      config = build(:api_configuration, :authorized)
      expect(config.oauth_status).to eq("Authorized")
    end
  end

  describe "#oauth_status_badge_class" do
    it 'returns "bg-secondary" when not authorized' do
      config = build(:api_configuration)
      expect(config.oauth_status_badge_class).to eq("bg-secondary")
    end

    it 'returns "bg-danger" when token is expired' do
      config = build(:api_configuration, :expired_token)
      expect(config.oauth_status_badge_class).to eq("bg-danger")
    end

    it 'returns "bg-success" when authorized with valid token' do
      config = build(:api_configuration, :authorized)
      expect(config.oauth_status_badge_class).to eq("bg-success")
    end
  end

  describe "enum api_name" do
    it "can be set to zerodha" do
      config = create(:api_configuration, api_name: :zerodha)
      expect(config.zerodha?).to be true
    end

    it "can be set to upstox" do
      config = create(:api_configuration, :upstox)
      expect(config.upstox?).to be true
    end

    it "can be set to angel_one" do
      config = create(:api_configuration, :angel_one)
      expect(config.angel_one?).to be true
    end
  end

  describe "oauth flow attributes" do
    let(:config) { create(:api_configuration) }

    it "can store oauth_state" do
      config.update(oauth_state: "random_state_123")
      expect(config.oauth_state).to eq("random_state_123")
    end

    it "can store redirect_uri" do
      config.update(redirect_uri: "https://example.com/callback")
      expect(config.redirect_uri).to eq("https://example.com/callback")
    end

    it "can update access_token" do
      config.update(access_token: "new_token_xyz")
      expect(config.access_token).to eq("new_token_xyz")
    end

    it "can update token_expires_at" do
      expiry_time = 1.day.from_now
      config.update(token_expires_at: expiry_time)
      expect(config.token_expires_at).to be_within(1.second).of(expiry_time)
    end
  end

  describe "dependent destroy" do
    let(:user) { create(:user) }

    it "is destroyed when associated user is destroyed" do
      config = create(:api_configuration, user: user)
      expect { user.destroy }.to change { ApiConfiguration.count }.by(-1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:api_configuration)).to be_valid
    end

    it "creates a valid api_configuration" do
      expect(create(:api_configuration)).to be_persisted
    end

    it "has a valid authorized trait" do
      config = create(:api_configuration, :authorized)
      expect(config).to be_valid
      expect(config.oauth_authorized?).to be true
      expect(config.token_expired?).to be false
    end

    it "has a valid expired_token trait" do
      config = create(:api_configuration, :expired_token)
      expect(config).to be_valid
      expect(config.oauth_authorized?).to be true
      expect(config.token_expired?).to be true
    end
  end
end
