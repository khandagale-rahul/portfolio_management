require "eventmachine"
require "faye/websocket"
require_relative "../../../lib/protobuf/upstox/MarketDataFeed_pb"

module Upstox
  class WebsocketService
    AUTHORIZE_URL = "https://api.upstox.com/v3/feed/market-data-feed/authorize"
    MAX_RECONNECT_ATTEMPTS = 10
    RECONNECT_DELAY = 5 # seconds
    HEARTBEAT_INTERVAL = 30 # seconds

    attr_reader :ws,
                :subscriptions,
                :on_message_callback,
                :on_error_callback,
                :on_connect_callback,
                :on_disconnect_callback

    def initialize(access_token, auto_reconnect: true)
      @access_token = access_token
      @ws = nil
      @subscriptions = []
      @on_message_callback = nil
      @on_error_callback = nil
      @on_connect_callback = nil
      @on_disconnect_callback = nil
      @ws_url = nil
      @auto_reconnect = auto_reconnect
      @reconnect_attempts = 0
      @intentional_disconnect = false
      @last_message_time = nil
      @heartbeat_timer = nil
    end

    def fetch_websocket_url
      begin
        response = RestClient::Request.execute(
          method: :get,
          url: AUTHORIZE_URL,
          timeout: 30,
          headers: {
            authorization: "Bearer #{@access_token}",
            accept: "application/json"
          }
        )

        data = JSON.parse(response.body)

        if data["status"] == "success" && data.dig("data", "authorized_redirect_uri")
          @ws_url = data["data"]["authorized_redirect_uri"]
          {
            success: true,
            ws_url: @ws_url
          }
        else
          {
            success: false,
            error: data["errors"] || "Failed to get WebSocket URL"
          }
        end
      rescue RestClient::ExceptionWithResponse => e
        error_data = JSON.parse(e.response.body) rescue {}
        Rails.logger.error "Upstox WebSocket authorization failed: #{e.message}"
        {
          success: false,
          error: error_data["errors"] || "HTTP #{e.http_code}: #{e.message}"
        }
      rescue StandardError => e
        Rails.logger.error "Upstox WebSocket authorization failed: #{e.message}"
        {
          success: false,
          error: "Connection error: #{e.message}"
        }
      end
    end

    def on_message(&block)
      @on_message_callback = block
    end

    def on_error(&block)
      @on_error_callback = block
    end

    def on_connect(&block)
      @on_connect_callback = block
    end

    def on_disconnect(&block)
      @on_disconnect_callback = block
    end

    def connect
      result = fetch_websocket_url
      unless result[:success]
        @on_error_callback&.call(result[:error])
        schedule_reconnect if @auto_reconnect
        return
      end

      @ws = Faye::WebSocket::Client.new(@ws_url)

      @ws.on :open do |event|
        Rails.logger.info "[MarketData] WebSocket connected to Upstox"
        @reconnect_attempts = 0
        @last_message_time = Time.current

        start_heartbeat_monitor

        resubscribe_on_reconnect if @subscriptions.any?

        @on_connect_callback&.call
      end

      @ws.on :message do |event|
        begin
          @last_message_time = Time.current
          message_data = nil

          begin
            feed_response = Com::Upstox::Marketdatafeederv3udapi::Rpc::Proto::FeedResponse.decode(event.data)

            parsed_feeds = {}
            feed_response.feeds.each do |instrument_key, feed|
              parsed_feeds[instrument_key] = parse_feed(feed)
            end

            message_data = {
              type: feed_response.type,
              feeds: parsed_feeds,
              current_ts: feed_response.currentTs,
              market_info: feed_response.marketInfo&.segmentStatus&.to_h
            }
          rescue NotImplementedError, NoMethodError, ArgumentError => e
            Rails.logger.warn "Protobuf decoding not available: #{e.message}. Message will be passed as raw data."

            if event.data.is_a?(String)
              begin
                message_data = JSON.parse(event.data, symbolize_names: true)
              rescue JSON::ParserError
                message_data = { raw_data: event.data, binary: !event.data.valid_encoding? }
              end
            else
              message_data = {
                error: "Binary protobuf data received but protobuf compiler not available",
                note: "Please compile MarketDataFeed.proto using: protoc --ruby_out=lib/protobuf lib/protobuf/MarketDataFeed.proto",
                data_size: event.data.bytesize
              }
            end
          end

          @on_message_callback&.call(message_data)
        rescue StandardError => e
          Rails.logger.error "[MarketData] Error processing WebSocket message: #{e.message}"
          @on_error_callback&.call("Message processing error: #{e.message}")
        end
      end

      @ws.on :error do |event|
        Rails.logger.error "[MarketData] WebSocket error: #{event.message}"
        @on_error_callback&.call(event.message)
      end

      @ws.on :close do |event|
        Rails.logger.info "[MarketData] WebSocket closed: #{event.code} - #{event.reason}"

        stop_heartbeat_monitor

        @ws = nil
        @on_disconnect_callback&.call(event.code, event.reason)

        unless @intentional_disconnect
          Rails.logger.warn "[MarketData] Unexpected disconnect, attempting reconnection..."
          schedule_reconnect if @auto_reconnect
        end
      end
    end

    # Subscribe to instrument keys with a specific mode
    # @param instrument_keys [Array<String>] Array of instrument keys (e.g., ["NSE_EQ|INE020B01018"])
    # @param mode [String] Subscription mode: "ltpc", "full", "option_greeks", "full_d30"
    def subscribe(instrument_keys, mode = "ltpc")
      return unless @ws

      message = {
        guid: SecureRandom.uuid,
        method: "sub",
        data: {
          mode: mode,
          instrumentKeys: instrument_keys
        }
      }
      json_data = message.to_json
      binary_data = json_data.b  # Convert to binary string (ASCII-8BIT encoding)
      @ws.send(binary_data)
      @subscriptions.concat(instrument_keys)
      Rails.logger.info "Subscribed to #{instrument_keys.join(', ')} in #{mode} mode"
    end

    # Unsubscribe from instrument keys
    # @param instrument_keys [Array<String>] Array of instrument keys to unsubscribe from
    def unsubscribe(instrument_keys)
      return unless @ws

      message = {
        guid: SecureRandom.uuid,
        method: "unsub",
        data: {
          instrumentKeys: instrument_keys
        }
      }

      json_data = message.to_json
      binary_data = json_data.b
      @ws.send(binary_data)
      @subscriptions -= instrument_keys
      Rails.logger.info "Unsubscribed from #{instrument_keys.join(', ')}"
    end

    # Change subscription mode for instrument keys
    # @param instrument_keys [Array<String>] Array of instrument keys
    # @param mode [String] New subscription mode: "ltpc", "full", "option_greeks", "full_d30"
    def change_mode(instrument_keys, mode)
      return unless @ws

      message = {
        guid: SecureRandom.uuid,
        method: "change_mode",
        data: {
          mode: mode,
          instrumentKeys: instrument_keys
        }
      }

      json_data = message.to_json
      binary_data = json_data.b  # Convert to binary string (ASCII-8BIT encoding)
      @ws.send(binary_data)
      Rails.logger.info "Changed mode to #{mode} for #{instrument_keys.join(', ')}"
    end

    def disconnect
      if @ws
        @intentional_disconnect = true
        stop_heartbeat_monitor
        @ws.close
        @ws = nil
        @subscriptions = []
        Rails.logger.info "[MarketData] WebSocket disconnected (intentional)"
      end
    end

    def connected?
      @ws && @ws.ready_state == Faye::WebSocket::API::OPEN
    end

    def connection_stats
      {
        connected: connected?,
        reconnect_attempts: @reconnect_attempts,
        subscriptions_count: @subscriptions.count,
        last_message_time: @last_message_time,
        seconds_since_last_message: @last_message_time ? (Time.current - @last_message_time).to_i : nil
      }
    end

    private

    def parse_feed(feed)
      result = {
        request_mode: feed.requestMode
      }

      case feed.FeedUnion
      when :ltpc
        result[:ltpc] = {
          ltp: feed.ltpc.ltp,
          ltt: feed.ltpc.ltt,
          ltq: feed.ltpc.ltq,
          cp: feed.ltpc.cp
        }
      when :fullFeed
        if feed.fullFeed.FullFeedUnion == :marketFF
          result[:market_full_feed] = parse_market_full_feed(feed.fullFeed.marketFF)
        elsif feed.fullFeed.FullFeedUnion == :indexFF
          result[:index_full_feed] = parse_index_full_feed(feed.fullFeed.indexFF)
        end
      when :firstLevelWithGreeks
        result[:first_level_with_greeks] = parse_first_level_with_greeks(feed.firstLevelWithGreeks)
      end

      result
    end

    def parse_market_full_feed(market_ff)
      {
        ltpc: parse_ltpc(market_ff.ltpc),
        market_level: market_ff.marketLevel&.bidAskQuote&.map { |q| parse_quote(q) },
        option_greeks: parse_option_greeks(market_ff.optionGreeks),
        market_ohlc: market_ff.marketOHLC&.ohlc&.map { |o| parse_ohlc(o) },
        atp: market_ff.atp,
        vtt: market_ff.vtt,
        oi: market_ff.oi,
        iv: market_ff.iv,
        tbq: market_ff.tbq,
        tsq: market_ff.tsq
      }
    end

    def parse_index_full_feed(index_ff)
      {
        ltpc: parse_ltpc(index_ff.ltpc),
        market_ohlc: index_ff.marketOHLC&.ohlc&.map { |o| parse_ohlc(o) }
      }
    end

    def parse_first_level_with_greeks(flwg)
      {
        ltpc: parse_ltpc(flwg.ltpc),
        first_depth: parse_quote(flwg.firstDepth),
        option_greeks: parse_option_greeks(flwg.optionGreeks),
        vtt: flwg.vtt,
        oi: flwg.oi,
        iv: flwg.iv
      }
    end

    def parse_ltpc(ltpc)
      return nil unless ltpc
      {
        ltp: ltpc.ltp,
        ltt: ltpc.ltt,
        ltq: ltpc.ltq,
        cp: ltpc.cp
      }
    end

    def parse_quote(quote)
      return nil unless quote
      {
        bid_quantity: quote.bidQ,
        bid_price: quote.bidP,
        ask_quantity: quote.askQ,
        ask_price: quote.askP
      }
    end

    def parse_option_greeks(greeks)
      return nil unless greeks
      {
        delta: greeks.delta,
        theta: greeks.theta,
        gamma: greeks.gamma,
        vega: greeks.vega,
        rho: greeks.rho
      }
    end

    def parse_ohlc(ohlc)
      return nil unless ohlc
      {
        interval: ohlc.interval,
        open: ohlc.open,
        high: ohlc.high,
        low: ohlc.low,
        close: ohlc.close,
        volume: ohlc.vol,
        timestamp: ohlc.ts
      }
    end

    def schedule_reconnect
      @reconnect_attempts += 1

      if @reconnect_attempts > MAX_RECONNECT_ATTEMPTS
        Rails.logger.error "[MarketData] Max reconnection attempts (#{MAX_RECONNECT_ATTEMPTS}) reached. Giving up."
        @on_error_callback&.call("Max reconnection attempts reached")
        return
      end

      # Exponential backoff: 5s, 10s, 20s, 40s, 80s, then cap at 120s
      delay = [ RECONNECT_DELAY * (2 ** (@reconnect_attempts - 1)), 120 ].min

      Rails.logger.info "[MarketData] Scheduling reconnection attempt #{@reconnect_attempts}/#{MAX_RECONNECT_ATTEMPTS} in #{delay} seconds"

      EM.add_timer(delay) do
        Rails.logger.info "[MarketData] Attempting reconnection #{@reconnect_attempts}/#{MAX_RECONNECT_ATTEMPTS}..."
        @intentional_disconnect = false
        connect
      end
    end

    # Resubscribe to instruments after reconnection
    def resubscribe_on_reconnect
      return if @subscriptions.empty?

      Rails.logger.info "[MarketData] Resubscribing to #{@subscriptions.count} instruments after reconnection"

      EM.add_timer(2) do
        if connected?
          subscribe(@subscriptions, "ltpc")
          Rails.logger.info "[MarketData] Resubscription completed"
        else
          Rails.logger.warn "[MarketData] Cannot resubscribe - not connected"
        end
      end
    end

    def start_heartbeat_monitor
      return if @heartbeat_timer

      @heartbeat_timer = EM.add_periodic_timer(HEARTBEAT_INTERVAL) do
        check_connection_health
      end
    end

    def stop_heartbeat_monitor
      if @heartbeat_timer
        @heartbeat_timer.cancel
        @heartbeat_timer = nil
      end
    end

    def check_connection_health
      return unless connected?

      if @last_message_time && (Time.current - @last_message_time) > (HEARTBEAT_INTERVAL * 3)
        Rails.logger.warn "[MarketData] No messages received for #{(Time.current - @last_message_time).to_i} seconds. Connection may be stale."

        if (Time.current - @last_message_time) > (HEARTBEAT_INTERVAL * 4)
          Rails.logger.error "[MarketData] Connection appears dead (no messages for #{(Time.current - @last_message_time).to_i}s). Forcing reconnection..."
          @intentional_disconnect = false
          @ws&.close
        end
      end
    end
  end
end
