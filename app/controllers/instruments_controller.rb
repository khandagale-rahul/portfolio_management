class InstrumentsController < ApplicationController
  def index
    @master_instruments = MasterInstrument.joins(:upstox_instrument).includes(
      :last_instrument_history, :upstox_instrument, :zerodha_instrument
    ).where.not(ltp: nil)

    # Apply sorting
    @master_instruments = apply_sorting(@master_instruments)
  end

  private

  def apply_sorting(relation)
    sort_column = params[:sort] || "name"
    sort_direction = params[:direction] || "asc"

    # Validate sort direction
    sort_direction = %w[asc desc].include?(sort_direction) ? sort_direction : "asc"

    case sort_column
    when "exchange"
      relation.order(exchange: sort_direction)
    when "exchange_token"
      relation.order(exchange_token: sort_direction)
    when "ltp"
      relation.order(ltp: sort_direction)
    when "change_percent"
      relation.order(
        Arel.sql("
          CASE
            WHEN ltp IS NULL OR previous_day_ltp IS NULL OR previous_day_ltp = 0 THEN NULL
            ELSE ((ltp - previous_day_ltp) / previous_day_ltp) * 100
          END #{sort_direction} NULLS LAST
        ")
      )
    else
      relation.order(name: sort_direction)
    end
  end
end
