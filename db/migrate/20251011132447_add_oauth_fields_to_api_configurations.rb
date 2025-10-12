class AddOauthFieldsToApiConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :api_configurations, :redirect_uri, :string
    add_column :api_configurations, :access_token, :string
    add_column :api_configurations, :token_expires_at, :datetime
    add_column :api_configurations, :oauth_state, :string
    add_column :api_configurations, :oauth_authorized_at, :datetime
  end
end
