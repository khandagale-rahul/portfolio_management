class MasterInstrument < ApplicationRecord
  belongs_to :zerodha_instrument, class_name: "ZerodhaInstrument", optional: true
  belongs_to :upstox_instrument, class_name: "UpstoxInstrument", optional: true

  has_many :instrument_histories, dependent: :destroy

  def self.create_from_exchange_data(instrument:, exchange:, exchange_token:)
    new_record = self.find_or_initialize_by(
      exchange: exchange,
      exchange_token: exchange_token
    )

    new_record.zerodha_instrument_id = instrument.id if instrument.is_a?(ZerodhaInstrument)
    new_record.upstox_instrument_id = instrument.id if instrument.is_a?(UpstoxInstrument)

    new_record.save!
    new_record
  end
end
