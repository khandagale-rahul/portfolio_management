class ApiConfiguration < ApplicationRecord
  enum :api_name, { zerodha: 1, upstock: 2, angel_one: 3 }

  validates :api_name, presence: true, uniqueness: { scope: :user_id, message: "has already been taken" }
end
