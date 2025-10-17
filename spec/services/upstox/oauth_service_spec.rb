require 'rails_helper'

RSpec.describe Upstox::OauthService do
  describe '.build_authorization_url' do
    let(:api_key) { 'test_api_key' }
    let(:redirect_uri) { 'https://example.com/callback' }
    let(:state) { 'random_state_token' }

    it 'builds the correct authorization URL with all parameters' do
      url = described_class.build_authorization_url(api_key, redirect_uri, state)

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h

      expect(uri.scheme).to eq('https')
      expect(uri.host).to eq('api.upstox.com')
      expect(uri.path).to eq('/v2/login/authorization/dialog')
      expect(params['response_type']).to eq('code')
      expect(params['client_id']).to eq(api_key)
      expect(params['redirect_uri']).to eq(redirect_uri)
      expect(params['state']).to eq(state)
    end

    it 'properly encodes special characters in parameters' do
      special_redirect_uri = 'https://example.com/callback?foo=bar&baz=qux'
      url = described_class.build_authorization_url(api_key, special_redirect_uri, state)

      expect(url).to include(CGI.escape(special_redirect_uri))
    end
  end

  describe '.exchange_code_for_token' do
    let(:api_key) { 'test_api_key' }
    let(:api_secret) { 'test_api_secret' }
    let(:code) { 'auth_code_123' }
    let(:redirect_uri) { 'https://example.com/callback' }
    let(:token_url) { Upstox::OauthService::TOKEN_URL }

    context 'when the token exchange is successful' do
      let(:successful_response) do
        {
          "access_token" => "test_access_token_abc123",
          "expires_in" => 86400,
          "token_type" => "Bearer"
        }.to_json
      end

      before do
        stub_request(:post, token_url)
          .with(
            body: {
              code: code,
              client_id: api_key,
              client_secret: api_secret,
              redirect_uri: redirect_uri,
              grant_type: "authorization_code"
            }
          )
          .to_return(status: 200, body: successful_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns success with access token and expiry' do
        result = described_class.exchange_code_for_token(api_key, api_secret, code, redirect_uri)

        expect(result[:success]).to be true
        expect(result[:access_token]).to eq('test_access_token_abc123')
        expect(result[:expires_at]).to be_a(Time)
        expect(result[:expires_at]).to be > Time.current
        expect(result[:raw_response]).to be_present
      end

      it 'calculates expiry correctly based on expires_in' do
        travel_to Time.zone.parse('2025-10-15 10:00:00') do
          result = described_class.exchange_code_for_token(api_key, api_secret, code, redirect_uri)

          expected_expiry = Time.current + 86400.seconds
          expect(result[:expires_at]).to be_within(1.second).of(expected_expiry)
        end
      end
    end

    context 'when the token exchange fails with API error' do
      let(:error_response) do
        {
          "status" => "error",
          "errors" => "Invalid authorization code"
        }.to_json
      end

      before do
        stub_request(:post, token_url)
          .to_return(status: 200, body: error_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns failure with error message' do
        result = described_class.exchange_code_for_token(api_key, api_secret, code, redirect_uri)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid authorization code')
      end
    end

    context 'when the token exchange fails with HTTP error' do
      before do
        stub_request(:post, token_url)
          .to_return(status: 401, body: { "errors" => "Unauthorized" }.to_json)
      end

      it 'returns failure with HTTP error details' do
        result = described_class.exchange_code_for_token(api_key, api_secret, code, redirect_uri)

        expect(result[:success]).to be false
        expect(result[:error]).to include('401')
      end
    end

    context 'when there is a network error' do
      before do
        stub_request(:post, token_url).to_raise(StandardError.new('Network timeout'))
      end

      it 'returns failure with connection error' do
        result = described_class.exchange_code_for_token(api_key, api_secret, code, redirect_uri)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Connection error')
        expect(result[:error]).to include('Network timeout')
      end
    end

    context 'when expires_in is not provided' do
      let(:response_without_expiry) do
        {
          "access_token" => "test_token",
          "token_type" => "Bearer"
        }.to_json
      end

      before do
        stub_request(:post, token_url)
          .to_return(status: 200, body: response_without_expiry)
      end

      it 'defaults to 24 hours expiry' do
        travel_to Time.zone.parse('2025-10-15 10:00:00') do
          result = described_class.exchange_code_for_token(api_key, api_secret, code, redirect_uri)

          expected_expiry = Time.current + 24.hours
          expect(result[:expires_at]).to be_within(1.second).of(expected_expiry)
        end
      end
    end
  end

  describe '.calculate_expiry (private method)' do
    it 'calculates expiry correctly when expires_in is provided' do
      travel_to Time.zone.parse('2025-10-15 10:00:00') do
        expiry = described_class.send(:calculate_expiry, 3600)
        expected = Time.current + 1.hour

        expect(expiry).to be_within(1.second).of(expected)
      end
    end

    it 'returns 24 hours expiry when expires_in is nil' do
      travel_to Time.zone.parse('2025-10-15 10:00:00') do
        expiry = described_class.send(:calculate_expiry, nil)
        expected = Time.current + 24.hours

        expect(expiry).to be_within(1.second).of(expected)
      end
    end

    it 'returns 24 hours expiry when expires_in is blank' do
      travel_to Time.zone.parse('2025-10-15 10:00:00') do
        expiry = described_class.send(:calculate_expiry, '')
        expected = Time.current + 24.hours

        expect(expiry).to be_within(1.second).of(expected)
      end
    end
  end

  describe 'constants' do
    it 'has correct AUTHORIZATION_URL' do
      expect(Upstox::OauthService::AUTHORIZATION_URL).to eq('https://api.upstox.com/v2/login/authorization/dialog')
    end

    it 'has correct TOKEN_URL' do
      expect(Upstox::OauthService::TOKEN_URL).to eq('https://api.upstox.com/v2/login/authorization/token')
    end
  end
end
