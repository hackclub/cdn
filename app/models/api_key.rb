# frozen_string_literal: true

class APIKey < ApplicationRecord
  belongs_to :user

  # Lockbox encryption
  has_encrypted :token

  # Blind index for token lookup
  blind_index :token

  before_validation :generate_token, on: :create

  validates :name, presence: true, length: { maximum: 255 }

  scope :active, -> { where(revoked: false) }
  scope :recent, -> { order(created_at: :desc) }

  # Find by token using blind index
  def self.find_by_token(token)
    find_by(token: token)  # Blind index handles lookup
  end

  def revoke!
    update!(revoked: true, revoked_at: Time.current)
  end

  def active?
    !revoked
  end

  def masked_token
    # Decrypt to get the full token, then mask it
    full = token
    prefix = full[0...13]  # "sk_cdn_" + first 6 chars
    suffix = full[-6..]     # Last 6 chars
    "#{prefix}....#{suffix}"
  end

  private

  def generate_token
    self.token ||= "sk_cdn_#{SecureRandom.hex(32)}"
  end
end
