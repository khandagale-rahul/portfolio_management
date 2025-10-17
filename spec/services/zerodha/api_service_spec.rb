require 'rails_helper'

RSpec.describe Zerodha::ApiService do
  let(:api_key) { 'test_api_key' }
  let(:access_token) { 'test_access_token' }
  let(:service) { described_class.new(api_key: api_key, access_token: access_token) }

  describe '#initialize' do
    it 'initializes with api_key and access_token' do
      expect(service.api_key).to eq(api_key)
      expect(service.access_token).to eq(access_token)
    end

    it 'raises error when initialized without required parameters' do
      expect {
        described_class.new
      }.to raise_error(ArgumentError)
    end
  end

  describe '#instruments' do
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/instruments" }

    context 'when the request is successful' do
      let(:csv_data) do
        "instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,exchange\n" \
        "408065,1594,INFY,INFOSYS LIMITED,1500.00,,0.00,0.05,1,EQ,NSE,NSE"
      end

      before do
        stub_request(:get, url)
          .with(headers: { 'Authorization' => "token #{api_key}:#{access_token}" })
          .to_return(status: 200, body: csv_data)
      end

      it 'fetches instruments successfully' do
        service.instruments

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:get, url).to_raise(StandardError.new('Connection failed'))
      end

      it 'returns failure status' do
        service.instruments

        expect(service.response['status']).to eq('failed')
        expect(service.response['message']).to include('Connection failed')
      end
    end
  end

  describe '#quote_ltp' do
    let(:instruments) { 'NSE:INFY' }
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/quote/ltp?i=#{instruments}" }

    context 'when the request is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "NSE:INFY" => { "last_price" => 1500.50 }
          }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches LTP successfully' do
        service.quote_ltp({ i: instruments })

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:get, url).to_raise(StandardError.new('API error'))
      end

      it 'returns failure status' do
        service.quote_ltp({ i: instruments })

        expect(service.response['status']).to eq('failed')
        expect(service.response['message']).to include('API error')
      end
    end
  end

  describe '#quote' do
    let(:instruments) { 'NSE:INFY' }
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/quote?i=#{instruments}" }

    context 'when the request is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "NSE:INFY" => {
              "last_price" => 1500.50,
              "ohlc" => { "open" => 1490, "high" => 1510, "low" => 1485, "close" => 1495 }
            }
          }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches full quote successfully' do
        service.quote({ i: instruments })

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end
  end

  describe '#place_order' do
    let(:variety) { 'regular' }
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/orders/#{variety}" }
    let(:order_params) do
      {
        variety: variety,
        tradingsymbol: 'INFY',
        exchange: 'NSE',
        transaction_type: 'BUY',
        order_type: 'LIMIT',
        quantity: 10,
        price: 1500,
        product: 'CNC'
      }
    end

    context 'when order placement is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => { "order_id" => "220101000000001" }
        }.to_json
      end

      before do
        stub_request(:post, url)
          .with(
            body: hash_including(order_params.except(:variety)),
            headers: { 'Authorization' => "token #{api_key}:#{access_token}" }
          )
          .to_return(status: 200, body: success_response)
      end

      it 'places order successfully' do
        service.place_order(order_params)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']['order_id']).to eq('220101000000001')
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

  describe '#get_all_orders' do
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/orders" }

    context 'when fetching orders is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "order_id" => "220101000000001" }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches all orders successfully' do
        service.get_all_orders

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#get_order_detail' do
    let(:order_id) { '220101000000001' }
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/orders/#{order_id}" }

    context 'when fetching order detail is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [{ "order_id" => order_id, "status" => "COMPLETE" }]
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches order detail successfully' do
        service.get_order_detail(order_id)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe '#modify_order' do
    let(:variety) { 'regular' }
    let(:order_id) { '220101000000001' }
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/orders/#{variety}/#{order_id}" }
    let(:modify_params) do
      {
        variety: variety,
        order_id: order_id,
        quantity: 20,
        price: 1510
      }
    end

    context 'when modification is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => { "order_id" => order_id }
        }.to_json
      end

      before do
        stub_request(:put, url)
          .to_return(status: 200, body: success_response)
      end

      it 'modifies order successfully' do
        service.modify_order(modify_params)

        expect(service.response['status']).to eq('success')
      end
    end
  end

  describe '#cancel_order' do
    let(:variety) { 'regular' }
    let(:order_id) { '220101000000001' }
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/orders/#{variety}/#{order_id}" }
    let(:cancel_params) { { variety: variety, order_id: order_id } }

    context 'when cancellation is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => { "order_id" => order_id }
        }.to_json
      end

      before do
        stub_request(:delete, url)
          .to_return(status: 200, body: success_response)
      end

      it 'cancels order successfully' do
        service.cancel_order(cancel_params)

        expect(service.response['status']).to eq('success')
      end
    end
  end

  describe '#get_positions' do
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/portfolio/positions" }

    context 'when fetching positions is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "net" => [{ "tradingsymbol" => "INFY", "quantity" => 10 }],
            "day" => [{ "tradingsymbol" => "INFY", "quantity" => 10 }]
          }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches positions successfully' do
        service.get_positions

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end
  end

  describe '#get_holdings' do
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/portfolio/holdings" }

    context 'when fetching holdings is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [
            {
              "tradingsymbol" => "INFY",
              "exchange" => "NSE",
              "quantity" => 50,
              "average_price" => 1400
            }
          ]
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

  describe '#user_equity_margins' do
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/user/margins/equity" }

    context 'when fetching margins is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => {
            "enabled" => true,
            "net" => 50000.00,
            "available" => {
              "live_balance" => 45000.00
            }
          }
        }.to_json
      end

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches equity margins successfully' do
        service.user_equity_margins

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_present
      end
    end
  end

  describe '#orders_charges' do
    let(:url) { "#{Zerodha::ApiService::BASE_URL}/charges/orders" }
    let(:charges_params) do
      {
        orders: [
          {
            tradingsymbol: 'INFY',
            exchange: 'NSE',
            transaction_type: 'BUY',
            quantity: 10,
            price: 1500,
            product: 'CNC'
          }
        ]
      }
    end

    context 'when fetching charges is successful' do
      let(:success_response) do
        {
          "status" => "success",
          "data" => [
            {
              "total" => 150.50,
              "breakdown" => {
                "brokerage" => 20.00,
                "stt" => 15.00
              }
            }
          ]
        }.to_json
      end

      before do
        stub_request(:post, url)
          .with(body: charges_params.to_json)
          .to_return(status: 200, body: success_response)
      end

      it 'fetches order charges successfully' do
        service.orders_charges(charges_params)

        expect(service.response['status']).to eq('success')
        expect(service.response['data']).to be_an(Array)
      end
    end
  end

  describe 'constants' do
    it 'has correct BASE_URL' do
      expect(Zerodha::ApiService::BASE_URL).to eq('https://api.kite.trade')
    end

    it 'has correct INSTRUMENTS_PATH' do
      expect(Zerodha::ApiService::INSTRUMENTS_PATH).to eq('/instruments')
    end
  end

  describe '#credentials (private method)' do
    it 'returns authorization header with api_key and access_token' do
      credentials = service.send(:credentials)
      expect(credentials[:Authorization]).to eq("token #{api_key}:#{access_token}")
    end
  end
end
