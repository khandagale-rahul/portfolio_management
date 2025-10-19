class MasterInstrument < ApplicationRecord
  belongs_to :zerodha_instrument, class_name: "ZerodhaInstrument", optional: true
  belongs_to :upstox_instrument, class_name: "UpstoxInstrument", optional: true

  has_many :instrument_histories, dependent: :destroy

  has_one :last_instrument_history, -> { order(created_at: :desc).limit(1) }, class_name: "InstrumentHistory"

  def self.create_from_exchange_data(name:, instrument:, exchange:, exchange_token:)
    record = self.find_or_initialize_by(
      exchange: exchange,
      exchange_token: exchange_token
    )

    record.zerodha_instrument_id = instrument.id if instrument.is_a?(ZerodhaInstrument)
    record.upstox_instrument_id = instrument.id if instrument.is_a?(UpstoxInstrument)
    record.name ||= name

    record.save!
    record
  end
end
