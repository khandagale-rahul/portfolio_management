class HoldingsController < ApplicationController
  before_action :set_holding, only: %i[ show ]

  # GET /holdings
  def index
    @holdings = current_user.holdings
  end

  # GET /holdings/1
  def show
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_holding
      @holding = current_user.holdings.find(params.expect(:id))
    end
end
