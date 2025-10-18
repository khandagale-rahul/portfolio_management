class Instrument < ApplicationRecord
  has_one :master_instrument, foreign_key: :upstox_instrument_id
  has_one :upstox_instrument, through: :master_instrument
  has_one :zerodha_instrument, through: :master_instrument

  has_many :instrument_histories, through: :master_instrument

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
