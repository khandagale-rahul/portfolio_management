class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_digest_changed?
  validates :name, presence: true
  validates :phone_number, presence: true, format: { with: /\A\+?[0-9]{10,15}\z/, message: "must be a valid phone number" }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
