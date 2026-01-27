# frozen_string_literal: true

class User < ApplicationRecord
  include PublicIdentifiable
  set_public_id_prefix :usr

  scope :admins, -> { where(is_admin: true) }

  validates :hca_id, presence: true, uniqueness: true
  encrypts :hca_access_token

  def self.find_or_create_from_omniauth(auth)
    hca_id = auth.uid
    raise "Missing HCA user ID from authentication" if hca_id.blank?

    find_or_create_by!(hca_id:) do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.hca_access_token = auth.credentials.token
    end
  end

  def hca_profile(access_token) = HCAService.new(access_token).me
end
