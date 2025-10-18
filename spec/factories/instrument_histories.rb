FactoryBot.define do
  factory :instrument_history do
    instrument { nil }
    unit { 1 }
    interval { 1 }
    date { "2025-10-17 21:01:12" }
  end
end
