FactoryBot.define do
  factory :master_instrument do
    zerodha_instrument { nil }
    upstox_instrument { nil }
  end
end
