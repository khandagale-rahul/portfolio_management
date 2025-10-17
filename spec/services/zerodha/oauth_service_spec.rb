require 'rails_helper'

RSpec.describe Zerodha::OauthService do
  describe '.build_authorization_url' do
    let(:api_key) { 'test_api_key' }
    let(:state) { 'random_state_token' }

    it 'builds the correct authorization URL with all parameters' do
      url = described_class.build_authorization_url(api_key, state)

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h

      expect(uri.scheme).to eq('https')
      expect(uri.host).to eq('kite.zerodha.com')
      expect(uri.path).to eq('/connect/login')
      expect(params['v']).to eq('3')
      expect(params['api_key']).to eq(api_key)
      expect(params['redirect_params']).to eq("state=#{state}")
    end

    it 'builds URL without redirect_params when state is blank' do
      url = described_class.build_authorization_url(api_key, '')

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h

      expect(params['v']).to eq('3')
      expect(params['api_key']).to eq(api_key)
      expect(params['redirect_params']).to be_nil
    end

    it 'builds URL without redirect_params when state is nil' do
      url = described_class.build_authorization_url(api_key, nil)

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h

      expect(params['v']).to eq('3')
      expect(params['api_key']).to eq(api_key)
      expect(params['redirect_params']).to be_nil
    end

    it 'properly encodes special characters in state' do
      special_state = 'state_with&special=chars'
      url = described_class.build_authorization_url(api_key, special_state)

      expect(url).to include(CGI.escape("state=#{special_state}"))
    end
  end

  describe '.exchange_token' do
    let(:api_key) { 'test_api_key' }
    let(:api_secret) { 'test_api_secret' }
    let(:request_token) { 'request_token_123' }
    let(:token_url) { Zerodha::OauthService::TOKEN_URL }

    describe 'checksum calculation' do
      it 'generates correct SHA-256 checksum' do
        expected_checksum = Digest::SHA256.hexdigest("#{api_key}#{request_token}#{api_secret}")

        stub_request(:post, token_url)
          .with(
            body: hash_including(checksum: expected_checksum)
          )
          .to_return(status: 200, body: {
            "status" => "success",
            "data" => { "access_token" => "test_token", "user_id" => "ABC123" }
          }.to_json)

        described_class.exchange_token(api_key, api_secret, request_token)
      end
    end

    context 'when the token exchange is successful' do
      let(:successful_response) do
        {
          "status" => "success",
          "data" => {
            "access_token" => "test_access_token_xyz",
            "user_id" => "ABC123",
            "user_name" => "Test User",
            "user_shortname" => "Test"
          }
        }.to_json
      end

      before do
        stub_request(:post, token_url)
          .to_return(status: 200, body: successful_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns success with access token and user details' do
        result = described_class.exchange_token(api_key, api_secret, request_token)

        expect(result[:success]).to be true
        expect(result[:access_token]).to eq('test_access_token_xyz')
        expect(result[:user_id]).to eq('ABC123')
        expect(result[:user_name]).to eq('Test User')
        expect(result[:user_shortname]).to eq('Test')
        expect(result[:raw_response]).to be_present
      end
    end

    context 'when the token exchange fails with API error' do
      let(:error_response) do
        {
          "status" => "error",
          "message" => "Invalid request token"
        }.to_json
      end

      before do
        stub_request(:post, token_url)
          .to_return(status: 200, body: error_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns failure with error message' do
        result = described_class.exchange_token(api_key, api_secret, request_token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid request token')
      end
    end

    context 'when the token exchange fails with HTTP error' do
      before do
        stub_request(:post, token_url)
          .to_return(status: 403, body: { "message" => "Forbidden" }.to_json)
      end

      it 'returns failure with HTTP error details' do
        result = described_class.exchange_token(api_key, api_secret, request_token)

        expect(result[:success]).to be false
        expect(result[:error]).to include('403')
      end
    end

    context 'when there is a network error' do
      before do
        stub_request(:post, token_url).to_raise(StandardError.new('Connection timeout'))
      end

      it 'returns failure with connection error' do
        result = described_class.exchange_token(api_key, api_secret, request_token)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Connection error')
        expect(result[:error]).to include('Connection timeout')
      end
    end

    context 'when access_token is missing in response' do
      let(:incomplete_response) do
        {
          "status" => "success",
          "data" => {
            "user_id" => "ABC123"
          }
        }.to_json
      end

      before do
        stub_request(:post, token_url)
          .to_return(status: 200, body: incomplete_response)
      end

      it 'returns failure with unknown error' do
        result = described_class.exchange_token(api_key, api_secret, request_token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Unknown error from Zerodha')
      end
    end
  end

  describe '.calculate_expiry' do
    context 'when current time is before 6 AM' do
      it 'returns today at 6 AM IST' do
        travel_to Time.zone.parse('2025-10-15 03:00:00 IST') do
          expiry = described_class.calculate_expiry

          expected_expiry = Time.zone.parse('2025-10-15 06:00:00 IST')
          expect(expiry).to eq(expected_expiry)
        end
      end
    end

    context 'when current time is after 6 AM' do
      it 'returns next day at 6 AM IST' do
        travel_to Time.zone.parse('2025-10-15 10:00:00 IST') do
          expiry = described_class.calculate_expiry

          expected_expiry = Time.zone.parse('2025-10-16 06:00:00 IST')
          expect(expiry).to eq(expected_expiry)
        end
      end
    end

    context 'when current time is exactly 6 AM' do
      it 'returns next day at 6 AM IST' do
        travel_to Time.zone.parse('2025-10-15 06:00:00 IST') do
          expiry = described_class.calculate_expiry

          expected_expiry = Time.zone.parse('2025-10-16 06:00:00 IST')
          expect(expiry).to eq(expected_expiry)
        end
      end
    end

    context 'when current time is just before 6 AM' do
      it 'returns today at 6 AM IST' do
        travel_to Time.zone.parse('2025-10-15 05:59:59 IST') do
          expiry = described_class.calculate_expiry

          expected_expiry = Time.zone.parse('2025-10-15 06:00:00 IST')
          expect(expiry).to be_within(1.second).of(expected_expiry)
        end
      end
    end

    context 'when current time is late at night' do
      it 'returns next day at 6 AM IST' do
        travel_to Time.zone.parse('2025-10-15 23:30:00 IST') do
          expiry = described_class.calculate_expiry

          expected_expiry = Time.zone.parse('2025-10-16 06:00:00 IST')
          expect(expiry).to eq(expected_expiry)
        end
      end
    end
  end

  describe 'constants' do
    it 'has correct AUTHORIZATION_URL' do
      expect(Zerodha::OauthService::AUTHORIZATION_URL).to eq('https://kite.zerodha.com/connect/login')
    end

    it 'has correct TOKEN_URL' do
      expect(Zerodha::OauthService::TOKEN_URL).to eq('https://api.kite.trade/session/token')
    end
  end
end
