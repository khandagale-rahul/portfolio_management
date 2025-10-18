class InstrumentHistory < ApplicationRecord
  belongs_to :master_instrument

  enum :unit, { minute: 1, hour: 2, day: 3, week: 4, month: 5 }
end
