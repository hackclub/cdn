# frozen_string_literal: true

class User < ApplicationRecord
  include PublicIdentifiable
  include PgSearch::Model
  set_public_id_prefix :usr
  def to_param = public_id

  pg_search_scope :search,
    against: [ :email, :name, :slack_id ],
    using: { tsearch: { prefix: true } }

  scope :admins, -> { where(is_admin: true) }

  validates :hca_id, presence: true, uniqueness: true
  validates :quota_policy, inclusion: { in: Quota::ADMIN_ASSIGNABLE.map(&:to_s) }, allow_nil: true
  encrypts :hca_access_token

  has_many :uploads, dependent: :destroy
  has_many :api_keys, dependent: :destroy, class_name: "APIKey"

  def self.find_or_create_from_omniauth(auth)
    hca_id = auth.uid
    slack_id = auth.extra.raw_info.slack_id
    raise "Missing HCA user ID from authentication" if hca_id.blank?

    user = find_by(hca_id:)
    user ||= find_by(slack_id:) if slack_id.present?

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

  def total_files
    uploads.count
  end

  def total_storage_bytes
    uploads.joins(:blob).sum("active_storage_blobs.byte_size")
  end

  def total_storage_gb
    (total_storage_bytes / 1.gigabyte.to_f).round(2)
  end

  def total_storage_formatted
    ActiveSupport::NumberHelper.number_to_human_size(total_storage_bytes)
  end
end
