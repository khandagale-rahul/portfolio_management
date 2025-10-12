class InstrumentsController < ApplicationController
  def index
    @upstox_instruments = UpstoxInstrument.all
    @zerodha_instruments = ZerodhaInstrument.all
  end
end
