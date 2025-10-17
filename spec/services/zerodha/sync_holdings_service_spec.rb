require 'rails_helper'

RSpec.describe Zerodha::SyncHoldingsService do
  let(:service) { described_class.new }

  describe '#initialize' do
    it 'initializes with zero counts and empty results' do
      expect(service.success_count).to eq(0)
      expect(service.error_count).to eq(0)
      expect(service.results).to eq([])
    end
  end

  describe '#sync_all' do
    context 'when there are no Zerodha API configurations' do
      before do
        relation = double('ActiveRecord::Relation')
        allow(relation).to receive(:where).and_return([])
        allow(ApiConfiguration).to receive(:zerodha).and_return(relation)
      end

      it 'returns success with zero counts' do
        result = service.sync_all

        expect(result[:success]).to be true
        expect(result[:message]).to include('No authorized Zerodha API configurations found')
        expect(result[:total_configs]).to eq(0)
        expect(result[:success_count]).to eq(0)
        expect(result[:error_count]).to eq(0)
        expect(result[:results]).to eq([])
      end
    end

    context 'when there are authorized Zerodha API configurations' do
      let(:user1) { create(:user, name: 'User One', email_address: 'user1@example.com') }
      let(:user2) { create(:user, name: 'User Two', email_address: 'user2@example.com') }
      let(:api_config1) do
        create(:api_configuration,
               user: user1,
               api_name: :zerodha,
               api_key: 'key1',
               access_token: 'token1',
               token_expires_at: 1.day.from_now)
      end
      let(:api_config2) do
        create(:api_configuration,
               user: user2,
               api_name: :zerodha,
               api_key: 'key2',
               access_token: 'token2',
               token_expires_at: 1.day.from_now)
      end

      before do
        relation = double('ActiveRecord::Relation')
        allow(relation).to receive(:where).and_return([api_config1, api_config2])
        allow(ApiConfiguration).to receive(:zerodha).and_return(relation)
      end

      it 'syncs holdings for all configurations' do
        expect(service).to receive(:sync_for_config).with(api_config1).and_call_original
        expect(service).to receive(:sync_for_config).with(api_config2).and_call_original

        # Mock the API responses
        allow_any_instance_of(Zerodha::ApiService).to receive(:get_holdings)
        allow_any_instance_of(Zerodha::ApiService).to receive(:response)
          .and_return({ 'status' => 'success', 'data' => [] })

        result = service.sync_all

        expect(result[:success]).to be true
        expect(result[:total_configs]).to eq(2)
        expect(result[:results].size).to eq(2)
      end
    end
  end

  describe '#sync_for_config' do
    let(:user) { create(:user, name: 'Test User', email_address: 'test@example.com') }
    let(:api_config) do
      create(:api_configuration,
             user: user,
             api_name: :zerodha,
             api_key: 'test_key',
             access_token: 'test_token',
             token_expires_at: 1.day.from_now)
    end

    context 'when the access token is expired' do
      before do
        api_config.update(token_expires_at: 1.day.ago)
      end

      it 'returns error result without calling API' do
        result = service.sync_for_config(api_config)

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('Access token expired')
        expect(result[:user_id]).to eq(user.id)
        expect(result[:user_name]).to eq('Test User')
        expect(result[:user_email]).to eq('test@example.com')
        expect(service.error_count).to eq(1)
      end
    end

    context 'when the API call is successful' do
      let(:holdings_data) do
        [
          {
            'tradingsymbol' => 'INFY',
            'exchange' => 'NSE',
            'quantity' => 10,
            'average_price' => 1400,
            'last_price' => 1500,
            'pnl' => 1000
          },
          {
            'tradingsymbol' => 'TCS',
            'exchange' => 'NSE',
            'quantity' => 5,
            'average_price' => 3200,
            'last_price' => 3400,
            'pnl' => 1000
          }
        ]
      end

      let(:api_service) { instance_double(Zerodha::ApiService) }

      before do
        allow(Zerodha::ApiService).to receive(:new)
          .with(api_key: api_config.api_key, access_token: api_config.access_token)
          .and_return(api_service)

        allow(api_service).to receive(:get_holdings)
        allow(api_service).to receive(:response)
          .and_return({ 'status' => 'success', 'data' => holdings_data })
      end

      it 'syncs holdings successfully' do
        result = service.sync_for_config(api_config)

        expect(result[:status]).to eq(:success)
        expect(result[:holdings_synced]).to eq(2)
        expect(result[:message]).to include('Successfully synced 2 holdings')
        expect(service.success_count).to eq(1)
      end

      it 'creates new holdings records' do
        expect {
          service.sync_for_config(api_config)
        }.to change { user.holdings.count }.by(2)

        infy_holding = user.holdings.find_by(trading_symbol: 'INFY', exchange: 'NSE')
        expect(infy_holding).to be_present
        expect(infy_holding.broker).to eq('zerodha')
        expect(infy_holding.data).to eq(holdings_data[0])
      end

      it 'updates existing holdings records' do
        # Create an existing holding
        existing_holding = user.holdings.create!(
          broker: :zerodha,
          exchange: 'NSE',
          trading_symbol: 'INFY',
          data: { 'quantity' => 5, 'average_price' => 1300 }
        )

        expect {
          service.sync_for_config(api_config)
        }.to change { user.holdings.count }.by(1)  # Only TCS is new

        existing_holding.reload
        expect(existing_holding.data['quantity']).to eq(10)
        expect(existing_holding.data['average_price']).to eq(1400)
      end
    end

    context 'when the API call fails' do
      let(:api_service) { instance_double(Zerodha::ApiService) }

      before do
        allow(Zerodha::ApiService).to receive(:new).and_return(api_service)
        allow(api_service).to receive(:get_holdings)
        allow(api_service).to receive(:response)
          .and_return({ 'status' => 'failed', 'message' => 'API error occurred' })
      end

      it 'returns error result' do
        result = service.sync_for_config(api_config)

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('API call failed')
        expect(result[:message]).to include('API error occurred')
        expect(service.error_count).to eq(1)
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Zerodha::ApiService).to receive(:new)
          .and_raise(StandardError.new('Network error'))
      end

      it 'returns error result with exception message' do
        result = service.sync_for_config(api_config)

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('Exception')
        expect(result[:message]).to include('Network error')
        expect(service.error_count).to eq(1)
      end
    end

    context 'when a holding fails to save' do
      let(:holdings_data) do
        [
          {
            'tradingsymbol' => 'INFY',
            'exchange' => 'NSE',
            'quantity' => 10
          }
        ]
      end

      let(:api_service) { instance_double(Zerodha::ApiService) }
      let(:invalid_holding) { instance_double(Holding, save: false, errors: double(full_messages: ['Validation failed'])) }

      before do
        allow(Zerodha::ApiService).to receive(:new).and_return(api_service)
        allow(api_service).to receive(:get_holdings)
        allow(api_service).to receive(:response)
          .and_return({ 'status' => 'success', 'data' => holdings_data })

        allow(user.holdings).to receive(:find_or_initialize_by).and_return(invalid_holding)
        allow(invalid_holding).to receive(:data=)
      end

      it 'includes error message in result' do
        result = service.sync_for_config(api_config)

        expect(result[:status]).to eq(:success)
        expect(result[:holdings_synced]).to eq(0)
        expect(result[:message]).to include('Some holdings failed to save')
        expect(result[:message]).to include('Validation failed')
      end
    end

    it 'includes all user and config details in result' do
      api_service = instance_double(Zerodha::ApiService)
      allow(Zerodha::ApiService).to receive(:new).and_return(api_service)
      allow(api_service).to receive(:get_holdings)
      allow(api_service).to receive(:response)
        .and_return({ 'status' => 'success', 'data' => [] })

      result = service.sync_for_config(api_config)

      expect(result[:user_id]).to eq(user.id)
      expect(result[:user_name]).to eq('Test User')
      expect(result[:user_email]).to eq('test@example.com')
      expect(result[:config_id]).to eq(api_config.id)
      expect(result).to have_key(:status)
      expect(result).to have_key(:message)
      expect(result).to have_key(:holdings_synced)
    end
  end

  describe 'integration test with sync_all' do
    let(:user1) { create(:user, name: 'User One', email_address: 'user1@example.com') }
    let(:user2) { create(:user, name: 'User Two', email_address: 'user2@example.com') }
    let(:api_config1) do
      create(:api_configuration,
             user: user1,
             api_name: :zerodha,
             api_key: 'key1',
             access_token: 'token1',
             token_expires_at: 1.day.from_now)
    end
    let(:api_config2) do
      create(:api_configuration,
             user: user2,
             api_name: :zerodha,
             api_key: 'key2',
             access_token: 'token2',
             token_expires_at: 1.day.ago)  # Expired
    end

    before do
      relation = double('ActiveRecord::Relation')
      allow(relation).to receive(:where).and_return([api_config1, api_config2])
      allow(ApiConfiguration).to receive(:zerodha).and_return(relation)

      api_service1 = instance_double(Zerodha::ApiService)
      allow(Zerodha::ApiService).to receive(:new)
        .with(api_key: 'key1', access_token: 'token1')
        .and_return(api_service1)
      allow(api_service1).to receive(:get_holdings)
      allow(api_service1).to receive(:response)
        .and_return({ 'status' => 'success', 'data' => [{ 'tradingsymbol' => 'INFY', 'exchange' => 'NSE' }] })
    end

    it 'handles mixed success and error results' do
      result = service.sync_all

      expect(result[:success]).to be true
      expect(result[:total_configs]).to eq(2)
      expect(result[:success_count]).to eq(1)
      expect(result[:error_count]).to eq(1)
      expect(result[:results].size).to eq(2)

      success_result = result[:results].find { |r| r[:status] == :success }
      error_result = result[:results].find { |r| r[:status] == :error }

      expect(success_result[:user_id]).to eq(user1.id)
      expect(error_result[:user_id]).to eq(user2.id)
      expect(error_result[:message]).to eq('Access token expired')
    end
  end
end
