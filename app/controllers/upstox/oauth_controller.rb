module Upstox
  class OauthController < ApplicationController
    before_action :set_api_configuration, only: [ :authorize ]

    # POST /upstox/oauth/authorize/:id
    # Initiates OAuth flow by redirecting to Upstox authorization URL
    def authorize
      unless @api_configuration.api_name == "upstox"
        redirect_to root_path, alert: "OAuth is only available for Upstox configurations."
        return
      end

      # Generate secure state token for CSRF protection
      state = SecureRandom.hex(32)

      # Store state in session for verification during callback
      session[:oauth_state] = state
      session[:oauth_api_config_id] = @api_configuration.id

      # Update api_configuration with state
      @api_configuration.update(oauth_state: state)

      # Build authorization URL
      authorization_url = ::Upstox::OauthService.build_authorization_url(
        @api_configuration.api_key,
        @api_configuration.redirect_uri,
        state
      )

      redirect_to authorization_url, allow_other_host: true
    end

    # GET /upstox/oauth/callback
    # Handles OAuth callback from Upstox
    def callback
      state = params[:state]

      # Verify state parameter to prevent CSRF attacks
      unless state.present? && state == session[:oauth_state]
        redirect_to root_path, alert: "Invalid OAuth state. Please try again."
        return
      end

      # Retrieve the API configuration
      api_config_id = session[:oauth_api_config_id]
      @api_configuration = current_user.api_configurations.find_by(id: api_config_id)

      unless @api_configuration
        redirect_to root_path, alert: "API configuration not found."
        return
      end

      # Exchange authorization code for access token
      result = ::Upstox::OauthService.exchange_code_for_token(
        @api_configuration.api_key,
        @api_configuration.api_secret,
        params[:code],
        @api_configuration.redirect_uri
      )

      if result[:success]
        # Store tokens in the database
        @api_configuration.update(
          access_token: result[:access_token],
          token_expires_at: result[:expires_at],
          oauth_authorized_at: Time.current,
          oauth_state: nil
        )

        # Clear session data
        session.delete(:oauth_state)
        session.delete(:oauth_api_config_id)

        redirect_to root_path, notice: "Successfully authorized with Upstox!"
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
