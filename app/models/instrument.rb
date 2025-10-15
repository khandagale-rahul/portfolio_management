class Instrument < ApplicationRecord
  has_one :upstox_instrument,
            -> { where(type: "UpstoxInstrument") },
            class_name: "UpstoxInstrument",
            foreign_key: :exchange_token,
            primary_key: :exchange_token
  has_one :zerodha_instrument,
          -> { where(type: "ZerodhaInstrument") },
          class_name: "ZerodhaInstrument",
          foreign_key: :exchange_token,
          primary_key: :exchange_token

  validates :identifier, presence: true, uniqueness: { scope: :type }
  validates :symbol,
            :name,
            :exchange,
            :segment,
            :identifier,
            :exchange_token,
            :tick_size,
            :lot_size,
            presence: true

  def display_name
    "#{symbol} - #{name} (#{exchange})"
  end
end
