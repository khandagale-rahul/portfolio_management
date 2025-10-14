class ApiConfiguration < ApplicationRecord
  belongs_to :user

  enum :api_name, { zerodha: 1, upstox: 2, angel_one: 3 }

  validates :api_name, presence: true, uniqueness: { scope: :user_id, message: "has already been taken" }
  validates :api_key, presence: true
  validates :api_secret, presence: true

  # Check if OAuth has been completed
  def oauth_authorized?
    oauth_authorized_at.present? && access_token.present?
  end

  # Check if the access token has expired
  def token_expired?
    return true if token_expires_at.blank?
    token_expires_at < Time.current
  end

  # Check if re-authorization is needed
  def requires_reauthorization?
    !oauth_authorized? || token_expired?
  end

  # Get OAuth status as human-readable string
  def oauth_status
    return "Not Authorized" unless oauth_authorized?
    return "Token Expired" if token_expired?
    "Authorized"
  end

  # Get OAuth status badge color for UI
  def oauth_status_badge_class
    return "bg-secondary" unless oauth_authorized?
    return "bg-danger" if token_expired?
    "bg-success"
  end
end
