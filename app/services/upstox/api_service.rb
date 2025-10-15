module Upstox
  class ApiService
    # Base URLs
    ASSETS_BASE_URL = "https://assets.upstox.com"
    API_BASE_URL = "https://api.upstox.com/v2"
    HFT_BASE_URL = "https://api-hft.upstox.com"

    # Paths
    INSTRUMENTS_PATH = "/market-quote/instruments/exchange"

    attr_reader :response, :api_key, :access_token

    def initialize(api_key: nil, access_token: nil)
      @api_key = api_key
      @access_token = access_token
    end

    def instruments(exchange: "NSE_MIS")
      url = "#{ASSETS_BASE_URL}#{INSTRUMENTS_PATH}/#{exchange}.json.gz"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40
        )

        { status: "success", data: api_response }
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access
      nil
    end

    # ============================================
    # ORDER MANAGEMENT
    # ============================================

    # Place order using V3 API with auto-slicing support
    # params: {
    #   quantity: integer (required)
    #   product: string (required) - "I" (Intraday), "D" (Delivery), "MTF" (Margin Trading)
    #   validity: string (required) - "DAY", "IOC"
    #   price: number (required)
    #   instrument_token: string (required) - e.g., "NSE_EQ|INE002A01018"
    #   order_type: string (required) - "MARKET", "LIMIT", "SL", "SL-M"
    #   transaction_type: string (required) - "BUY", "SELL"
    #   disclosed_quantity: integer (required)
    #   trigger_price: number (required)
    #   is_amo: boolean (required) - After Market Order flag
    #   tag: string (optional) - Order identifier
    #   slice: boolean (optional) - Auto-slice large orders
    # }
    def place_order(params)
      url = "#{HFT_BASE_URL}/v3/order/place"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :post,
          url: url,
          timeout: 5,
          payload: params.to_json,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Modify an existing order
    # params: {
    #   order_id: string (required)
    #   quantity: integer (optional)
    #   validity: string (optional) - "DAY", "IOC"
    #   price: number (optional)
    #   order_type: string (optional) - "MARKET", "LIMIT", "SL", "SL-M"
    #   disclosed_quantity: integer (optional)
    #   trigger_price: number (optional)
    # }
    def modify_order(params)
      url = "#{HFT_BASE_URL}/v2/order/modify"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :put,
          url: url,
          timeout: 5,
          payload: params.to_json,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Cancel an order
    # params: {
    #   order_id: string (required)
    # }
    def cancel_order(params)
      url = "#{HFT_BASE_URL}/v2/order/cancel?order_id=#{params[:order_id]}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :delete,
          url: url,
          timeout: 5,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Get all orders for the day
    def get_order_book
      url = "#{API_BASE_URL}/order/retrieve-all"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 5,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    alias_method :get_all_orders, :get_order_book

    # Get details of a specific order
    # order_id: string (required)
    def get_order_details(order_id)
      url = "#{API_BASE_URL}/order/details?order_id=#{order_id}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    alias_method :get_order_detail, :get_order_details

    # Get order history for a specific order
    # order_id: string (required)
    def get_order_history(order_id)
      url = "#{API_BASE_URL}/order/history?order_id=#{order_id}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Get all trades for the day
    def get_trades
      url = "#{API_BASE_URL}/order/trades/get-trades-for-day"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Get trades for a specific order
    # order_id: string (required)
    def get_order_trades(order_id)
      url = "#{API_BASE_URL}/order/trades?order_id=#{order_id}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # ============================================
    # PORTFOLIO & POSITIONS
    # ============================================

    # Get current positions
    def get_positions
      url = "#{API_BASE_URL}/portfolio/short-term-positions"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Get long term holdings
    def get_holdings
      url = "#{API_BASE_URL}/portfolio/long-term-holdings"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Convert position
    # params: {
    #   instrument_token: string (required)
    #   new_product: string (required) - "I", "D", "MTF"
    #   old_product: string (required) - "I", "D", "MTF"
    #   transaction_type: string (required) - "BUY", "SELL"
    #   quantity: integer (required)
    # }
    def convert_position(params)
      url = "#{API_BASE_URL}/portfolio/convert-position"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :put,
          url: url,
          timeout: 5,
          payload: params.to_json,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # ============================================
    # USER & MARGINS
    # ============================================

    # Get user profile
    def get_profile
      url = "#{API_BASE_URL}/user/profile"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Get funds and margin details
    # segment: string (optional) - "SEC" (Securities/Equity), "COM" (Commodity)
    def get_fund_margin(segment: nil)
      url = if segment
        "#{API_BASE_URL}/user/get-funds-and-margin?segment=#{segment}"
      else
        "#{API_BASE_URL}/user/get-funds-and-margin"
      end

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    alias_method :user_equity_margins, :get_fund_margin

    # ============================================
    # MARKET QUOTES
    # ============================================

    # Get LTP (Last Traded Price) for instruments
    # params: {
    #   instrument_keys: string (required) - Comma separated instrument tokens
    #                    e.g., "NSE_EQ|INE002A01018,NSE_EQ|INE467B01029"
    # }
    def quote_ltp(params)
      url = "#{API_BASE_URL}/market-quote/ltp?instrument_key=#{params[:instrument_keys]}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Get full market quote for instruments
    # params: {
    #   instrument_keys: string (required) - Comma separated instrument tokens
    # }
    def quote(params)
      url = "#{API_BASE_URL}/market-quote/quotes?instrument_key=#{params[:instrument_keys]}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    # Get OHLC (Open, High, Low, Close) data
    # params: {
    #   instrument_keys: string (required) - Comma separated instrument tokens
    #   interval: string (required) - "1minute", "30minute", "day", "week", "month"
    # }
    def get_ohlc(params)
      url = "#{API_BASE_URL}/market-quote/ohlc?instrument_key=#{params[:instrument_keys]}&interval=#{params[:interval]}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    private

    def credentials
      { "Authorization": "Bearer #{@access_token}" }
    end
  end
end
