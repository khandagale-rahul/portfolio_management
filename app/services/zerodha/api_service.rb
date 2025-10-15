module Zerodha
  class ApiService
    BASE_URL = "https://api.kite.trade"
    INSTRUMENTS_PATH = "/instruments"

    attr_reader :response, :api_key, :access_token

    def initialize(api_key:, access_token:)
      @api_key = api_key
      @access_token = access_token
    end

    def instruments
      url = "#{BASE_URL}#{INSTRUMENTS_PATH}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          timeout: 40,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        { status: "success", data: api_response }
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    def quote_ltp(params)
      url = "#{BASE_URL}/quote/ltp?i=#{params[:i]}"

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

    def quote(params)
      url = "#{BASE_URL}/quote?i=#{params[:i]}"

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

    def place_order(params)
      url = "#{BASE_URL}/orders/#{params[:variety]}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :post,
          url: url,
          timeout: 5,
          payload: params,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    def get_all_orders
      url = "#{BASE_URL}/orders"

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

    def get_order_detail(order_id)
      url = "#{BASE_URL}/orders/#{order_id}"

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

    def modify_order(params)
      url = "#{BASE_URL}/orders/#{params[:variety]}/#{params[:order_id]}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :put,
          url: url,
          payload: params,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    def cancel_order(params)
      url = "#{BASE_URL}/orders/#{params[:variety]}/#{params[:order_id]}"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :delete,
          url: url,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    def get_positions
      url = "#{BASE_URL}/portfolio/positions"

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

    def user_equity_margins
      url = "#{BASE_URL}/user/margins/equity"

      @response = begin
        api_response = RestClient::Request.execute(
          method: :get,
          url: url,
          headers: credentials.merge({ 'Content-Type': "application/json" })
        )

        JSON.parse(api_response)
      rescue => e
        error_message = e.http_body rescue e.message
        { status: "failed", message: error_message }
      end.with_indifferent_access

      nil
    end

    def orders_charges(params)
      url = "#{BASE_URL}/charges/orders"

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

    def get_holdings
      url = "#{BASE_URL}/portfolio/holdings"

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
      { "Authorization": "token #{@api_key}:#{@access_token}" }
    end
  end
end
