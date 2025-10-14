module DashboardHelper
  def oauth_path_for(config)
    if config.upstox?
      upstox_oauth_authorize_path(config)
    elsif config.zerodha?
      zerodha_oauth_authorize_path(config)
    else
      "#"
    end
  end
end
