class InstrumentHistoriesController < ApplicationController
  before_action :set_instrument_history, only: %i[ show edit update destroy ]

  # GET /instrument_histories
  def index
    @instrument_histories = InstrumentHistory.all
  end

  # GET /instrument_histories/1
  def show
  end

  # GET /instrument_histories/new
  def new
    @instrument_history = InstrumentHistory.new
  end

  # GET /instrument_histories/1/edit
  def edit
  end

  # POST /instrument_histories
  def create
    @instrument_history = InstrumentHistory.new(instrument_history_params)

    if @instrument_history.save
      redirect_to @instrument_history, notice: "Instrument history was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /instrument_histories/1
  def update
    if @instrument_history.update(instrument_history_params)
      redirect_to @instrument_history, notice: "Instrument history was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /instrument_histories/1
  def destroy
    @instrument_history.destroy!
    redirect_to instrument_histories_path, notice: "Instrument history was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_instrument_history
      @instrument_history = InstrumentHistory.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def instrument_history_params
      params.expect(instrument_history: [ :instrument_id, :unit, :interval, :date ])
    end
end
