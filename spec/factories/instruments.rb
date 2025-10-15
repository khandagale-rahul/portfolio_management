FactoryBot.define do
  factory :instrument, class: 'Instrument' do
    type { "Instrument" }
    symbol { Faker::Finance.ticker }
    name { Faker::Company.name }
    exchange { "NSE" }
    segment { "NSE_EQ" }
    identifier { Faker::Number.number(digits: 10).to_s }
    exchange_token { Faker::Number.number(digits: 6).to_s }
    tick_size { 0.05 }
    lot_size { 1 }
    raw_data { {} }
  end

  factory :upstox_instrument, class: 'UpstoxInstrument', parent: :instrument do
    type { "UpstoxInstrument" }
    segment { "NSE_MIS" }
    identifier { "NSE_EQ|INE#{Faker::Number.number(digits: 6)}" }
    raw_data do
      {
        "instrument_key" => identifier,
        "exchange_token" => exchange_token,
        "trading_symbol" => symbol,
        "name" => name,
        "last_price" => 1500.50,
        "exchange" => exchange,
        "segment" => segment,
        "tick_size" => tick_size,
        "lot_size" => lot_size
      }
    end
  end

  factory :zerodha_instrument, class: 'ZerodhaInstrument', parent: :instrument do
    type { "ZerodhaInstrument" }
    segment { "NSE" }
    identifier { Faker::Number.number(digits: 9).to_s }
    raw_data do
      {
        "instrument_token" => identifier,
        "exchange_token" => exchange_token,
        "tradingsymbol" => symbol,
        "name" => name,
        "last_price" => 1500.50,
        "exchange" => exchange,
        "segment" => segment,
        "tick_size" => tick_size,
        "lot_size" => lot_size,
        "instrument_type" => "EQ"
      }
    end
  end
end
