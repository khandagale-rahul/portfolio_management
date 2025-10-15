FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email_address { Faker::Internet.email }
    phone_number { Faker::PhoneNumber.cell_phone_in_e164.gsub(/\D/, '')[0..14] }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
