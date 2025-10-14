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

    private

      def credentials
        { "Authorization": "token #{@api_key}:#{@access_token}" }
      end
  end
end
