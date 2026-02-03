class Quota
  Policy = Data.define(:slug, :max_file_size, :max_total_storage)

  ALL_POLICIES = [
    Policy[:unverified, 10.megabytes, 50.megabytes],
    Policy[:verified, 100.megabytes, 50.gigabytes],
    Policy[:functionally_unlimited, 500.megabytes, 300.gigabytes]
  ].index_by &:slug

  ADMIN_ASSIGNABLE = %i[verified functionally_unlimited].freeze

  def self.policy(slug) = ALL_POLICIES.fetch slug
end
