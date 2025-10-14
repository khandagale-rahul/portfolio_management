module Upstox
  class OauthService
    AUTHORIZATION_URL = "https://api.upstox.com/v2/login/authorization/dialog"
    TOKEN_URL = "https://api.upstox.com/v2/login/authorization/token"

    class << self
      # Builds the Upstox OAuth authorization URL
      # @param api_key [String] The API key (client_id)
      # @param redirect_uri [String] The callback URL
      # @param state [String] CSRF protection token
      # @return [String] The complete authorization URL
      def build_authorization_url(api_key, redirect_uri, state)
        params = {
          response_type: "code",
          client_id: api_key,
          redirect_uri: redirect_uri,
          state: state
        }

        uri = URI(AUTHORIZATION_URL)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      # Exchanges authorization code for access token
      # @param api_key [String] The API key (client_id)
      # @param api_secret [String] The API secret (client_secret)
      # @param code [String] The authorization code from callback
      # @param redirect_uri [String] The callback URL (must match)
      # @return [Hash] Result hash with :success, :access_token, :expires_at, or :error
      def exchange_code_for_token(api_key, api_secret, code, redirect_uri)
        params = {
          code: code,
          client_id: api_key,
          client_secret: api_secret,
          redirect_uri: redirect_uri,
          grant_type: "authorization_code"
        }

        begin
          response = RestClient::Request.execute(
            method: :post,
            url: TOKEN_URL,
            payload: params,
            timeout: 30,
            headers: { content_type: :url_encoded_form }
          )

          data = JSON.parse(response.body)

          if data["access_token"]
            {
              success: true,
              access_token: data["access_token"],
              expires_at: calculate_expiry(data["expires_in"]),
              raw_response: data
            }
          else
            {
              success: false,
              error: data["errors"] || "Unknown error from Upstox"
            }
          end
        rescue RestClient::ExceptionWithResponse => e
          error_data = JSON.parse(e.response.body) rescue {}
          Rails.logger.error "Upstox OAuth token exchange failed: #{e.message}"
          {
            success: false,
            error: error_data["errors"] || "HTTP #{e.http_code}: #{e.message}"
          }
        rescue StandardError => e
          Rails.logger.error "Upstox OAuth token exchange failed: #{e.message}"
          {
            success: false,
            error: "Connection error: #{e.message}"
          }
        end
      end

      private

      # Calculates token expiration time
      # @param expires_in [Integer] Seconds until expiration (from Upstox response)
      # @return [Time] The expiration timestamp
      def calculate_expiry(expires_in)
        if expires_in.present?
          Time.current + expires_in.to_i.seconds
        else
          # Default to 24 hours if not specified
          Time.current + 24.hours
        end
      end
    end
  end
end
