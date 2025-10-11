class ApiConfigurationsController < ApplicationController
  before_action :set_api_configuration, only: %i[ show edit update destroy ]

  # GET /api_configurations
  def index
    @api_configurations = current_user.api_configurations
  end

  # GET /api_configurations/1
  def show
  end

  # GET /api_configurations/new
  def new
    @api_configuration = ApiConfiguration.new
  end

  # GET /api_configurations/1/edit
  def edit
  end

  # POST /api_configurations
  def create
    @api_configuration = current_user.api_configurations.new(api_configuration_params)

    if @api_configuration.save
      redirect_to @api_configuration, notice: "Api configuration was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api_configurations/1
  def update
    if @api_configuration.update(api_configuration_params)
      redirect_to @api_configuration, notice: "Api configuration was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /api_configurations/1
  def destroy
    @api_configuration.destroy!
    redirect_to api_configurations_path, notice: "Api configuration was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_api_configuration
      @api_configuration = current_user.api_configurations.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def api_configuration_params
      params.require(:api_configuration).permit(:api_name, :api_key, :api_secret)
    end
end
