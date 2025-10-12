class DashboardController < ApplicationController
  def index
    @api_configurations = current_user.api_configurations.order(created_at: :desc)
  end
end
