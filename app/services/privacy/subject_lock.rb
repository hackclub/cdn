require "digest"

module Privacy
  module SubjectLock
    # Coordinate Slack enqueue/processing with erasure, without storing identifiers.
    def self.acquire!(slack_ids, wait: false)
      slack_ids.compact.uniq.sort.each do |slack_id|
        lock_id = Digest::SHA256.digest("cdn-privacy-slack:#{slack_id}").unpack1("q>")
        sql = wait ? "SELECT pg_advisory_xact_lock($1)" : "SELECT pg_try_advisory_xact_lock($1)"
        bind = ActiveRecord::Relation::QueryAttribute.new("privacy_lock", lock_id, ActiveRecord::Type::Integer.new(limit: 8))
        acquired = User.connection.exec_query(sql, "Privacy subject lock", [ bind ]).rows.first.first
        raise Error.new("manual_review_required", 409) if !wait && !acquired
      end
    end
  end
end
