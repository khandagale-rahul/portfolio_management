require 'rails_helper'

RSpec.describe Upstox::WebsocketService do
  let(:access_token) { 'test_access_token' }
  let(:service) { described_class.new(access_token) }
  let(:authorize_url) { Upstox::WebsocketService::AUTHORIZE_URL }

  describe '#initialize' do
    it 'initializes with access token and defaults' do
      expect(service.instance_variable_get(:@access_token)).to eq(access_token)
      expect(service.instance_variable_get(:@auto_reconnect)).to be true
      expect(service.subscriptions).to eq([])
      expect(service.ws).to be_nil
    end

    it 'can disable auto_reconnect' do
      service = described_class.new(access_token, auto_reconnect: false)
      expect(service.instance_variable_get(:@auto_reconnect)).to be false
    end
  end

  describe '#fetch_websocket_url' do
    context 'when authorization is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "authorized_redirect_uri" => "wss://ws.upstox.com/v3/feed?token=xyz"
          }
        }.to_json
      end

      before do
        stub_request(:get, authorize_url)
          .with(headers: { 'Authorization' => "Bearer #{access_token}" })
          .to_return(status: 200, body: success_response)
      end

      it 'fetches WebSocket URL successfully' do
        result = service.fetch_websocket_url

        expect(result[:success]).to be true
        expect(result[:ws_url]).to eq("wss://ws.upstox.com/v3/feed?token=xyz")
        expect(service.instance_variable_get(:@ws_url)).to eq("wss://ws.upstox.com/v3/feed?token=xyz")
      end
    end

    context 'when authorization fails' do
      let(:error_response) do
        {
          "status" => "error",
          "errors" => "Invalid token"
        }.to_json
      end

      before do
        stub_request(:get, authorize_url)
          .to_return(status: 200, body: error_response)
      end

      it 'returns error message' do
        result = service.fetch_websocket_url

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid token")
      end
    end

    context 'when there is an HTTP error' do
      before do
        stub_request(:get, authorize_url)
          .to_return(status: 401, body: { "errors" => "Unauthorized" }.to_json)
      end

      it 'returns HTTP error details' do
        result = service.fetch_websocket_url

        expect(result[:success]).to be false
        expect(result[:error]).to include('401')
      end
    end

    context 'when there is a network error' do
      before do
        stub_request(:get, authorize_url)
          .to_raise(StandardError.new('Network timeout'))
      end

      it 'returns connection error' do
        result = service.fetch_websocket_url

        expect(result[:success]).to be false
        expect(result[:error]).to include('Connection error')
        expect(result[:error]).to include('Network timeout')
      end
    end
  end

  describe 'callback setters' do
    it 'sets on_message callback' do
      callback = ->(msg) { puts msg }
      service.on_message(&callback)
      expect(service.on_message_callback).to eq(callback)
    end

    it 'sets on_error callback' do
      callback = ->(err) { puts err }
      service.on_error(&callback)
      expect(service.on_error_callback).to eq(callback)
    end

    it 'sets on_connect callback' do
      callback = -> { puts "connected" }
      service.on_connect(&callback)
      expect(service.on_connect_callback).to eq(callback)
    end

    it 'sets on_disconnect callback' do
      callback = ->(code, reason) { puts "disconnected: #{code}" }
      service.on_disconnect(&callback)
      expect(service.on_disconnect_callback).to eq(callback)
    end
  end

  describe '#connected?' do
    context 'when WebSocket is connected' do
      let(:mock_ws) { double('WebSocket', ready_state: Faye::WebSocket::API::OPEN) }

      before do
        service.instance_variable_set(:@ws, mock_ws)
      end

      it 'returns true' do
        expect(service.connected?).to be true
      end
    end

    context 'when WebSocket is not connected' do
      it 'returns false when ws is nil' do
        expect(service.connected?).to be false
      end

      it 'returns false when ws is closed' do
        mock_ws = double('WebSocket', ready_state: Faye::WebSocket::API::CLOSED)
        service.instance_variable_set(:@ws, mock_ws)

        expect(service.connected?).to be false
      end
    end
  end

  describe '#connection_stats' do
    before do
      travel_to Time.zone.parse('2025-10-15 10:00:00')
    end

    it 'returns connection statistics' do
      service.instance_variable_set(:@reconnect_attempts, 2)
      service.instance_variable_set(:@subscriptions, ['NSE_EQ|INE002A01018'])
      service.instance_variable_set(:@last_message_time, 5.minutes.ago)

      stats = service.connection_stats

      expect(stats[:connected]).to be false
      expect(stats[:reconnect_attempts]).to eq(2)
      expect(stats[:subscriptions_count]).to eq(1)
      expect(stats[:last_message_time]).to be_within(1.second).of(5.minutes.ago)
      expect(stats[:seconds_since_last_message]).to eq(300)
    end

    it 'returns nil for seconds_since_last_message when no messages received' do
      stats = service.connection_stats

      expect(stats[:seconds_since_last_message]).to be_nil
    end
  end

  describe '#subscribe' do
    let(:instrument_keys) { ['NSE_EQ|INE002A01018', 'NSE_EQ|INE467B01029'] }
    let(:mode) { 'ltpc' }
    let(:mock_ws) { double('WebSocket', send: true) }

    before do
      service.instance_variable_set(:@ws, mock_ws)
    end

    it 'sends subscription message and adds to subscriptions' do
      expect(mock_ws).to receive(:send) do |data|
        message = JSON.parse(data)
        expect(message['method']).to eq('sub')
        expect(message['data']['mode']).to eq(mode)
        expect(message['data']['instrumentKeys']).to eq(instrument_keys)
        expect(message['guid']).to be_present
      end

      service.subscribe(instrument_keys, mode)

      expect(service.subscriptions).to eq(instrument_keys)
    end

    it 'defaults to ltpc mode' do
      expect(mock_ws).to receive(:send) do |data|
        message = JSON.parse(data)
        expect(message['data']['mode']).to eq('ltpc')
      end

      service.subscribe(instrument_keys)
    end

    it 'does nothing when ws is nil' do
      service.instance_variable_set(:@ws, nil)

      expect {
        service.subscribe(instrument_keys, mode)
      }.not_to raise_error

      expect(service.subscriptions).to be_empty
    end
  end

  describe '#unsubscribe' do
    let(:instrument_keys) { ['NSE_EQ|INE002A01018'] }
    let(:mock_ws) { double('WebSocket', send: true) }

    before do
      service.instance_variable_set(:@ws, mock_ws)
      service.instance_variable_set(:@subscriptions, instrument_keys.dup)
    end

    it 'sends unsubscribe message and removes from subscriptions' do
      expect(mock_ws).to receive(:send) do |data|
        message = JSON.parse(data)
        expect(message['method']).to eq('unsub')
        expect(message['data']['instrumentKeys']).to eq(instrument_keys)
        expect(message['guid']).to be_present
      end

      service.unsubscribe(instrument_keys)

      expect(service.subscriptions).to be_empty
    end

    it 'does nothing when ws is nil' do
      service.instance_variable_set(:@ws, nil)
      initial_subscriptions = service.subscriptions.dup

      expect {
        service.unsubscribe(instrument_keys)
      }.not_to raise_error

      expect(service.subscriptions).to eq(initial_subscriptions)
    end
  end

  describe '#change_mode' do
    let(:instrument_keys) { ['NSE_EQ|INE002A01018'] }
    let(:mode) { 'full' }
    let(:mock_ws) { double('WebSocket', send: true) }

    before do
      service.instance_variable_set(:@ws, mock_ws)
    end

    it 'sends change_mode message' do
      expect(mock_ws).to receive(:send) do |data|
        message = JSON.parse(data)
        expect(message['method']).to eq('change_mode')
        expect(message['data']['mode']).to eq(mode)
        expect(message['data']['instrumentKeys']).to eq(instrument_keys)
        expect(message['guid']).to be_present
      end

      service.change_mode(instrument_keys, mode)
    end

    it 'does nothing when ws is nil' do
      service.instance_variable_set(:@ws, nil)

      expect {
        service.change_mode(instrument_keys, mode)
      }.not_to raise_error
    end
  end

  describe '#disconnect' do
    let(:mock_ws) { double('WebSocket', close: true, ready_state: Faye::WebSocket::API::OPEN) }

    before do
      service.instance_variable_set(:@ws, mock_ws)
      service.instance_variable_set(:@subscriptions, ['NSE_EQ|INE002A01018'])
      service.instance_variable_set(:@heartbeat_timer, double('Timer', cancel: true))
    end

    it 'closes WebSocket connection and clears state' do
      expect(mock_ws).to receive(:close)

      service.disconnect

      expect(service.ws).to be_nil
      expect(service.subscriptions).to be_empty
      expect(service.instance_variable_get(:@intentional_disconnect)).to be true
    end

    it 'does nothing when ws is nil' do
      service.instance_variable_set(:@ws, nil)

      expect {
        service.disconnect
      }.not_to raise_error
    end
  end

  describe 'constants' do
    it 'has correct AUTHORIZE_URL' do
      expect(Upstox::WebsocketService::AUTHORIZE_URL).to eq('https://api.upstox.com/v3/feed/market-data-feed/authorize')
    end

    it 'has correct MAX_RECONNECT_ATTEMPTS' do
      expect(Upstox::WebsocketService::MAX_RECONNECT_ATTEMPTS).to eq(10)
    end

    it 'has correct RECONNECT_DELAY' do
      expect(Upstox::WebsocketService::RECONNECT_DELAY).to eq(5)
    end

    it 'has correct HEARTBEAT_INTERVAL' do
      expect(Upstox::WebsocketService::HEARTBEAT_INTERVAL).to eq(30)
    end
  end

  describe 'private methods' do
    describe '#parse_ltpc' do
      it 'parses LTPC data' do
        ltpc = double('LTPC', ltp: 3500.50, ltt: Time.now.to_i, ltq: 100, cp: 3400.00)
        result = service.send(:parse_ltpc, ltpc)

        expect(result[:ltp]).to eq(3500.50)
        expect(result[:ltq]).to eq(100)
        expect(result[:cp]).to eq(3400.00)
      end

      it 'returns nil when ltpc is nil' do
        result = service.send(:parse_ltpc, nil)
        expect(result).to be_nil
      end
    end

    describe '#parse_quote' do
      it 'parses quote data' do
        quote = double('Quote', bidQ: 50, bidP: 3500, askQ: 60, askP: 3501)
        result = service.send(:parse_quote, quote)

        expect(result[:bid_quantity]).to eq(50)
        expect(result[:bid_price]).to eq(3500)
        expect(result[:ask_quantity]).to eq(60)
        expect(result[:ask_price]).to eq(3501)
      end

      it 'returns nil when quote is nil' do
        result = service.send(:parse_quote, nil)
        expect(result).to be_nil
      end
    end

    describe '#parse_option_greeks' do
      it 'parses option greeks data' do
        greeks = double('Greeks', delta: 0.5, theta: -0.02, gamma: 0.01, vega: 0.15, rho: 0.03)
        result = service.send(:parse_option_greeks, greeks)

        expect(result[:delta]).to eq(0.5)
        expect(result[:theta]).to eq(-0.02)
        expect(result[:gamma]).to eq(0.01)
        expect(result[:vega]).to eq(0.15)
        expect(result[:rho]).to eq(0.03)
      end

      it 'returns nil when greeks is nil' do
        result = service.send(:parse_option_greeks, nil)
        expect(result).to be_nil
      end
    end

    describe '#parse_ohlc' do
      it 'parses OHLC data' do
        ohlc = double('OHLC', interval: '1minute', open: 3500, high: 3510, low: 3490, close: 3505, vol: 1000, ts: Time.now.to_i)
        result = service.send(:parse_ohlc, ohlc)

        expect(result[:interval]).to eq('1minute')
        expect(result[:open]).to eq(3500)
        expect(result[:high]).to eq(3510)
        expect(result[:low]).to eq(3490)
        expect(result[:close]).to eq(3505)
        expect(result[:volume]).to eq(1000)
      end

      it 'returns nil when ohlc is nil' do
        result = service.send(:parse_ohlc, nil)
        expect(result).to be_nil
      end
    end
  end
end
