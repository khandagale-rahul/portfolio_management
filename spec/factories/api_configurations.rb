FactoryBot.define do
  factory :api_configuration do
    user
    api_name { :zerodha }
    api_key { Faker::Alphanumeric.alphanumeric(number: 32) }
    api_secret { Faker::Alphanumeric.alphanumeric(number: 32) }
    access_token { nil }
    token_expires_at { nil }
    oauth_state { nil }
    oauth_authorized_at { nil }
    redirect_uri { nil }

    trait :upstox do
      api_name { :upstox }
    end

    trait :angel_one do
      api_name { :angel_one }
    end

    trait :authorized do
      access_token { Faker::Alphanumeric.alphanumeric(number: 64) }
      oauth_authorized_at { Time.current }
      token_expires_at { 1.day.from_now }
    end

    trait :expired_token do
      access_token { Faker::Alphanumeric.alphanumeric(number: 64) }
      oauth_authorized_at { 2.days.ago }
      token_expires_at { 1.day.ago }
    end
  end
end
