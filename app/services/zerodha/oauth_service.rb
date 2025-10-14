require "net/http"
require "uri"
require "json"
require "digest"

module Zerodha
  class OauthService
    AUTHORIZATION_URL = "https://kite.zerodha.com/connect/login"
    TOKEN_URL = "https://api.kite.trade/session/token"

    class << self
      def build_authorization_url(api_key, state)
        params = {
          v: "3",
          api_key: api_key
        }

        if state.present?
          params[:redirect_params] = "state=#{state}"
        end

        uri = URI(AUTHORIZATION_URL)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def exchange_token(api_key, api_secret, request_token)
        uri = URI(TOKEN_URL)

        checksum = Digest::SHA256.hexdigest("#{api_key}#{request_token}#{api_secret}")

        params = {
          api_key: api_key,
          request_token: request_token,
          checksum: checksum
        }

        headers = {
          "Content-Type" => "application/x-www-form-urlencoded"
        }

        begin
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri.path, headers)
          request.set_form_data(params)

          response = http.request(request)

          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)

            if data["status"] == "success" && data["data"]["access_token"]
              {
                success: true,
                access_token: data["data"]["access_token"],
                user_id: data["data"]["user_id"],
                user_name: data["data"]["user_name"],
                user_shortname: data["data"]["user_shortname"],
                raw_response: data
              }
            else
              {
                success: false,
                error: data["message"] || "Unknown error from Zerodha"
              }
            end
          else
            error_data = JSON.parse(response.body) rescue {}
            {
              success: false,
              error: error_data["message"] || "HTTP #{response.code}: #{response.message}"
            }
          end
        rescue StandardError => e
          Rails.logger.error "Zerodha OAuth token exchange failed: #{e.message}"
          {
            success: false,
            error: "Connection error: #{e.message}"
          }
        end
      end

      def calculate_expiry
        current_time = Time.current

        next_day_6am = current_time.tomorrow.beginning_of_day + 6.hours

        today_6am = current_time.beginning_of_day + 6.hours
        if current_time < today_6am
          today_6am
        else
          next_day_6am
        end
      end
    end
  end
end
