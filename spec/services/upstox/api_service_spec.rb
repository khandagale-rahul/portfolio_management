require 'rails_helper'

RSpec.describe Upstox::ApiService do
  let(:api_key) { 'test_api_key' }
  let(:access_token) { 'test_access_token' }
  let(:service) { described_class.new(api_key: api_key, access_token: access_token) }

  describe '#initialize' do
    it 'initializes with api_key and access_token' do
      expect(service.api_key).to eq(api_key)
      expect(service.access_token).to eq(access_token)
    end

    it 'can be initialized without parameters' do
      service = described_class.new
      expect(service.api_key).to be_nil
      expect(service.access_token).to be_nil
    end
  end

  describe '#instruments' do
    let(:exchange) { 'NSE_MIS' }
    let(:url) { "#{Upstox::ApiService::ASSETS_BASE_URL}/market-quote/instruments/exchange/#{exchange}.json.gz" }

    context 'when the request is successful' do
      let(:instruments_data) { '[{"instrument_key":"NSE_EQ|INE002A01018","exchange":"NSE"}]' }

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: instruments_data)
      end

      it 'fetches instruments successfully' do
        service.instruments(exchange: exchange)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:get, url).to_raise(StandardError.new('Connection failed'))
      end

      it 'returns failure status' do
        service.instruments(exchange: exchange)

        expect(service.response['status']).to eq('failed')
        expect(service.response['message']).to include('Connection failed')
      end
    end

    it 'defaults to NSE_MIS exchange' do
      expect(RestClient::Request).to receive(:execute).with(
        hash_including(url: "#{Upstox::ApiService::ASSETS_BASE_URL}/market-quote/instruments/exchange/NSE_MIS.json.gz")
      ).and_return('')

      service.instruments
    end
  end

  describe '#place_order' do
    let(:url) { "#{Upstox::ApiService::HFT_BASE_URL}/v3/order/place" }
    let(:order_params) do
      {
        quantity: 10,
        product: 'I',
        validity: 'DAY',
        price: 100.50,
        instrument_token: 'NSE_EQ|INE002A01018',
        order_type: 'LIMIT',
        transaction_type: 'BUY',
        disclosed_quantity: 0,
        trigger_price: 0,
        is_amo: false
      }
    end

    context 'when order placement is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => { "order_id" => "240101000000001" }
        }.to_json
      end

      before do
        stub_request(:post, url)
          .with(
            body: order_params.to_json,
            headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' }
          )
          .to_return(status: 200, body: success_response)
      end

      it 'places order successfully' do
        service.place_order(order_params)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']['order_id']).to eq('240101000000001')
      end
    end

    context 'when order placement fails' do
      before do
        stub_request(:post, url).to_raise(StandardError.new('Order failed'))
      end

      it 'returns failure status' do
        service.place_order(order_params)

        expect(service.response['status']).to eq('failed')
        expect(service.response['message']).to include('Order failed')
      end
    end
  end

  describe '#modify_order' do
    let(:url) { "#{Upstox::ApiService::HFT_BASE_URL}/v2/order/modify" }
    let(:modify_params) do
      { order_id: '240101000000001', quantity: 20, price: 105.00 }
    end

    context 'when modification is successful' do
      let(:success_response) { { "status" => "success" }.to_json }

      before do
        stub_request(:put, url)
          .with(body: modify_params.to_json)
          .to_return(status: 200, body: success_response)
      end

      it 'modifies order successfully' do
        service.modify_order(modify_params)

        expect(service.response['status']).to eq('success')
      end
    end
  end

  describe '#cancel_order' do
    let(:order_id) { '240101000000001' }
    let(:url) { "#{Upstox::ApiService::HFT_BASE_URL}/v2/order/cancel?order_id=#{order_id}" }

    context 'when cancellation is successful' do
      let(:success_response) { { "status" => "success" }.to_json }

      before do
        stub_request(:delete, url)
          .to_return(status: 200, body: success_response)
      end

      it 'cancels order successfully' do
        service.cancel_order({ order_id: order_id })

        expect(service.response['status']).to eq('success')
      end
    end
  end

  describe '#get_order_book' do
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/order/retrieve-all" }

    context 'when fetching order book is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "order_id" => "240101000000001" }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches order book successfully' do
        service.get_order_book

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#get_all_orders' do
    it 'is an alias for get_order_book' do
      expect(service.method(:get_all_orders)).to eq(service.method(:get_order_book))
    end
  end

  describe '#get_order_details' do
    let(:order_id) { '240101000000001' }
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/order/details?order_id=#{order_id}" }

    context 'when fetching order details is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => { "order_id" => order_id }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches order details successfully' do
        service.get_order_details(order_id)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']['order_id']).to eq(order_id)
      end
    end
  end

  describe '#get_order_detail' do
    it 'is an alias for get_order_details' do
      expect(service.method(:get_order_detail)).to eq(service.method(:get_order_details))
    end
  end

  describe '#get_order_history' do
    let(:order_id) { '240101000000001' }
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/order/history?order_id=#{order_id}" }

    context 'when fetching order history is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "order_id" => order_id, "status" => "complete" }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches order history successfully' do
        service.get_order_history(order_id)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#get_trades' do
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/order/trades/get-trades-for-day" }

    context 'when fetching trades is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "trade_id" => "T001" }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches trades successfully' do
        service.get_trades

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#get_order_trades' do
    let(:order_id) { '240101000000001' }
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/order/trades?order_id=#{order_id}" }

    context 'when fetching order trades is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "trade_id" => "T001", "order_id" => order_id }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches order trades successfully' do
        service.get_order_trades(order_id)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#get_positions' do
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/portfolio/short-term-positions" }

    context 'when fetching positions is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "instrument_token" => "NSE_EQ|INE002A01018" }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches positions successfully' do
        service.get_positions

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#get_holdings' do
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/portfolio/long-term-holdings" }

    context 'when fetching holdings is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "isin" => "INE002A01018" }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches holdings successfully' do
        service.get_holdings

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#convert_position' do
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/portfolio/convert-position" }
    let(:convert_params) do
      {
        instrument_token: 'NSE_EQ|INE002A01018',
        new_product: 'D',
        old_product: 'I',
        transaction_type: 'BUY',
        quantity: 10
      }
    end

    context 'when conversion is successful' do
      let(:success_response) { { "status" => "success" }.to_json }

      before do
        stub_request(:put, url)
          .with(body: convert_params.to_json)
          .to_return(status: 200, body: success_response)
      end

      it 'converts position successfully' do
        service.convert_position(convert_params)

        expect(service.response['status']).to eq('success')
      end
    end
  end

  describe '#get_profile' do
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/user/profile" }

    context 'when fetching profile is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => { "email" => "test@example.com" }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches profile successfully' do
        service.get_profile

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end
  end

  describe '#get_fund_margin' do
    context 'without segment parameter' do
      let(:url) { "#{Upstox::ApiService::API_BASE_URL}/user/get-funds-and-margin" }

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: { "status" => "success", "data" => {} }.to_json)
      end

      it 'fetches fund margin without segment' do
        service.get_fund_margin

        expect(service.response['status']).to eq('success')
      end
    end

    context 'with segment parameter' do
      let(:segment) { 'SEC' }
      let(:url) { "#{Upstox::ApiService::API_BASE_URL}/user/get-funds-and-margin?segment=#{segment}" }

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: { "status" => "success", "data" => {} }.to_json)
      end

      it 'fetches fund margin with segment' do
        service.get_fund_margin(segment: segment)

        expect(service.response['status']).to eq('success')
      end
    end
  end

  describe '#user_equity_margins' do
    it 'is an alias for get_fund_margin' do
      expect(service.method(:user_equity_margins)).to eq(service.method(:get_fund_margin))
    end
  end

  describe '#quote_ltp' do
    let(:instrument_keys) { 'NSE_EQ|INE002A01018,NSE_EQ|INE467B01029' }
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/market-quote/ltp?instrument_key=#{instrument_keys}" }

    context 'when fetching LTP is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "NSE_EQ|INE002A01018" => { "last_price" => 3500.50 }
          }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches LTP successfully' do
        service.quote_ltp({ instrument_keys: instrument_keys })

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end
  end

  describe '#quote' do
    let(:instrument_keys) { 'NSE_EQ|INE002A01018' }
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/market-quote/quotes?instrument_key=#{instrument_keys}" }

    context 'when fetching quote is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "NSE_EQ|INE002A01018" => { "ohlc" => { "open" => 3500 } }
          }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches quote successfully' do
        service.quote({ instrument_keys: instrument_keys })

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end
  end

  describe '#get_ohlc' do
    let(:instrument_keys) { 'NSE_EQ|INE002A01018' }
    let(:interval) { 'day' }
    let(:url) { "#{Upstox::ApiService::API_BASE_URL}/market-quote/ohlc?instrument_key=#{instrument_keys}&interval=#{interval}" }

    context 'when fetching OHLC is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "NSE_EQ|INE002A01018" => { "ohlc" => { "open" => 3500, "high" => 3600 } }
          }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches OHLC successfully' do
        service.get_ohlc({ instrument_keys: instrument_keys, interval: interval })

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end
  end

  describe 'constants' do
    it 'has correct ASSETS_BASE_URL' do
      expect(Upstox::ApiService::ASSETS_BASE_URL).to eq('https://assets.upstox.com')
    end

    it 'has correct API_BASE_URL' do
      expect(Upstox::ApiService::API_BASE_URL).to eq('https://api.upstox.com/v2')
    end

    it 'has correct HFT_BASE_URL' do
      expect(Upstox::ApiService::HFT_BASE_URL).to eq('https://api-hft.upstox.com')
    end

    it 'has correct INSTRUMENTS_PATH' do
      expect(Upstox::ApiService::INSTRUMENTS_PATH).to eq('/market-quote/instruments/exchange')
    end
  end

  describe '#credentials (private method)' do
    it 'returns authorization header with bearer token' do
      credentials = service.send(:credentials)
      expect(credentials[:Authorization]).to eq("Bearer #{access_token}")
    end
  end
end
