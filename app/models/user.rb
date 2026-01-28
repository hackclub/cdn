# frozen_string_literal: true

class User < ApplicationRecord
  include PublicIdentifiable
  set_public_id_prefix :usr

  scope :admins, -> { where(is_admin: true) }

  validates :hca_id, presence: true, uniqueness: true
  encrypts :hca_access_token

  def self.find_or_create_from_omniauth(auth)
    hca_id = auth.uid
    slack_id = auth.extra.raw_info.slack_id
    raise "Missing HCA user ID from authentication" if hca_id.blank?

    user = find_by(hca_id:) || find_by(slack_id:)

    if user
      user.update(
        hca_id:,
        slack_id:,
        email: auth.info.email,
        name: auth.info.name,
        hca_access_token: auth.credentials.token
      )
    else
      user = create!(
        hca_id:,
        slack_id:,
        email: auth.info.email,
        name: auth.info.name,
        hca_access_token: auth.credentials.token
      )
    end

    user
  end

  def hca_profile(access_token) = HCAService.new(access_token).me
end
