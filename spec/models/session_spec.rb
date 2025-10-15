require 'rails_helper'

RSpec.describe Session, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "attributes" do
    let(:user) { create(:user) }

    it "stores ip_address" do
      session = create(:session, user: user, ip_address: "192.168.1.1")
      expect(session.ip_address).to eq("192.168.1.1")
    end

    it "stores user_agent" do
      user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
      session = create(:session, user: user, user_agent: user_agent)
      expect(session.user_agent).to eq(user_agent)
    end

    it "allows nil ip_address" do
      session = build(:session, user: user, ip_address: nil)
      expect(session).to be_valid
    end

    it "allows nil user_agent" do
      session = build(:session, user: user, user_agent: nil)
      expect(session).to be_valid
    end
  end

  describe "creation" do
    let(:user) { create(:user) }

    it "creates a valid session with all attributes" do
      session = create(:session,
        user: user,
        ip_address: "192.168.1.100",
        user_agent: "Test Browser"
      )

      expect(session).to be_persisted
      expect(session.user).to eq(user)
      expect(session.ip_address).to eq("192.168.1.100")
      expect(session.user_agent).to eq("Test Browser")
    end

    it "sets timestamps automatically" do
      session = create(:session, user: user)
      expect(session.created_at).to be_present
      expect(session.updated_at).to be_present
    end
  end

  describe "association behavior" do
    let(:user) { create(:user) }

    it "can create multiple sessions for the same user" do
      session1 = create(:session, user: user, ip_address: "192.168.1.1")
      session2 = create(:session, user: user, ip_address: "192.168.1.2")

      expect(user.sessions.count).to eq(2)
      expect(user.sessions).to include(session1, session2)
    end

    it "is destroyed when associated user is destroyed" do
      session = create(:session, user: user)
      expect { user.destroy }.to change { Session.count }.by(-1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:session)).to be_valid
    end

    it "creates a valid session" do
      expect(create(:session)).to be_persisted
    end

    it "generates unique IP addresses" do
      sessions = create_list(:session, 3)
      ip_addresses = sessions.map(&:ip_address)
      expect(ip_addresses.uniq.count).to be > 1
    end
  end
end
