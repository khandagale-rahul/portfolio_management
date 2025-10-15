FactoryBot.define do
  factory :holding do
    user
    broker { :zerodha }
    exchange { "NSE" }
    trading_symbol { Faker::Finance.ticker }
    data do
      {
        "quantity" => 10,
        "average_price" => 1500.50,
        "last_price" => 1550.00,
        "pnl" => 495.00
      }
    end

    trait :upstox do
      broker { :upstox }
    end

    trait :angel_one do
      broker { :angel_one }
    end
  end
end
