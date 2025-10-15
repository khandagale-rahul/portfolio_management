require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:api_configurations).dependent(:destroy) }
    it { is_expected.to have_many(:holdings).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    context "presence validations" do
      it { is_expected.to validate_presence_of(:email_address) }
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:phone_number) }

      it "validates password presence on create" do
        user = build(:user, password: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end
    end

    context "uniqueness validations" do
      it "validates uniqueness of email_address" do
        create(:user, email_address: "test@example.com")
        duplicate_user = build(:user, email_address: "test@example.com")
        expect(duplicate_user).not_to be_valid
        expect(duplicate_user.errors[:email_address]).to include("has already been taken")
      end
    end

    context "format validations" do
      it "validates email format" do
        user = build(:user, email_address: "invalid-email")
        expect(user).not_to be_valid
        expect(user.errors[:email_address]).to include("is invalid")
      end

      it "accepts valid email formats" do
        valid_emails = ["user@example.com", "test.user@example.co.in", "user+tag@example.com"]
        valid_emails.each do |email|
          user = build(:user, email_address: email)
          expect(user).to be_valid
        end
      end

      it "validates phone number format" do
        invalid_phones = ["12345", "abc1234567", "123-456-7890"]
        invalid_phones.each do |phone|
          user = build(:user, phone_number: phone)
          expect(user).not_to be_valid
          expect(user.errors[:phone_number]).to include("must be a valid phone number")
        end
      end

      it "accepts valid phone number formats" do
        valid_phones = ["9876543210", "+919876543210", "1234567890123"]
        valid_phones.each do |phone|
          user = build(:user, phone_number: phone)
          expect(user).to be_valid
        end
      end
    end

    context "password validations" do
      it "validates minimum password length" do
        user = build(:user, password: "12345", password_confirmation: "12345")
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("is too short (minimum is 6 characters)")
      end

      it "accepts password with minimum length" do
        user = build(:user, password: "123456", password_confirmation: "123456")
        expect(user).to be_valid
      end

      it "only validates password when it changes" do
        user = create(:user, password: "password123")
        user.name = "Updated Name"
        expect(user).to be_valid
      end
    end
  end

  describe "normalizations" do
    it "normalizes email_address by stripping whitespace and downcasing" do
      user = create(:user, email_address: "  TeSt@ExAmPlE.CoM  ")
      expect(user.email_address).to eq("test@example.com")
    end
  end

  describe "secure password" do
    it "encrypts password using has_secure_password" do
      user = create(:user, password: "password123")
      expect(user.password_digest).not_to eq("password123")
      expect(user.password_digest).to be_present
    end

    it "authenticates user with correct password" do
      user = create(:user, password: "password123")
      expect(user.authenticate("password123")).to eq(user)
    end

    it "does not authenticate user with incorrect password" do
      user = create(:user, password: "password123")
      expect(user.authenticate("wrongpassword")).to be_falsey
    end
  end

  describe "dependent destroy" do
    let(:user) { create(:user) }

    it "destroys associated sessions when user is destroyed" do
      session = create(:session, user: user)
      expect { user.destroy }.to change { Session.count }.by(-1)
    end

    it "destroys associated api_configurations when user is destroyed" do
      api_config = create(:api_configuration, user: user)
      expect { user.destroy }.to change { ApiConfiguration.count }.by(-1)
    end

    it "destroys associated holdings when user is destroyed" do
      holding = create(:holding, user: user)
      expect { user.destroy }.to change { Holding.count }.by(-1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:user)).to be_valid
    end

    it "creates a valid user" do
      expect(create(:user)).to be_persisted
    end
  end
end
