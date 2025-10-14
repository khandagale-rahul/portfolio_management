module Zerodha
  class OauthController < ApplicationController
    before_action :set_api_configuration, only: [ :authorize ]

    def authorize
      unless @api_configuration.api_name == "zerodha"
        redirect_to root_path, alert: "OAuth is only available for Zerodha configurations."
        return
      end

      state = SecureRandom.hex(32)

      session[:oauth_state] = state
      session[:oauth_api_config_id] = @api_configuration.id

      @api_configuration.update(oauth_state: state)

      authorization_url = ::Zerodha::OauthService.build_authorization_url(
        @api_configuration.api_key,
        state
      )

      redirect_to authorization_url, allow_other_host: true
    end

    def callback
      state = params[:state]

      unless state.present? && state == session[:oauth_state]
        redirect_to root_path, alert: "Invalid OAuth state. Please try again."
        return
      end

      api_config_id = session[:oauth_api_config_id]
      @api_configuration = current_user.api_configurations.find_by(id: api_config_id)

      unless @api_configuration
        redirect_to root_path, alert: "API configuration not found."
        return
      end

      result = ::Zerodha::OauthService.exchange_token(
        @api_configuration.api_key,
        @api_configuration.api_secret,
        params[:request_token]
      )

      if result[:success]
        token_expires_at = ::Zerodha::OauthService.calculate_expiry

        @api_configuration.update(
          access_token: result[:access_token],
          token_expires_at: token_expires_at,
          oauth_authorized_at: Time.current,
          oauth_state: nil
        )

        session.delete(:oauth_state)
        session.delete(:oauth_api_config_id)

        redirect_to root_path, notice: "Successfully authorized with Zerodha!"
      else
        redirect_to root_path, alert: "Failed to authorize: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to root_path, alert: "An error occurred during authorization: #{e.message}"
    end

    private

    def set_api_configuration
      @api_configuration = current_user.api_configurations.find(params[:id])
    end
  end
end
