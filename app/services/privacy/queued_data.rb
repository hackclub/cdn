module Privacy
  class QueuedData
    EXECUTIONS = %w[blocked claimed failed ready recurring scheduled].freeze

    def initialize(subject, users, uploads)
      @slack_ids = ([ subject["slack_id"] ] + users.map(&:slack_id)).compact
      @urls = uploads.map(&:assets_url)
    end

    def available?
      # No persistent queue is configured in development or the default test suite.
      Rails.application.config.active_job.queue_adapter == :solid_queue || SolidQueue::Job.table_exists?
    end

    def transaction(&block)
      available? ? SolidQueue::Job.transaction(requires_new: true, &block) : yield
    end

    def plan(lock:)
      return [] unless available?
      jobs = SolidQueue::Job.where(class_name: %w[ProcessSlackFileUploadJob PurgeCloudflareCacheJob]).order(:id)
      jobs = jobs.lock if lock
      jobs.select do |job|
        args = job.arguments.fetch("arguments", [])
        if job.class_name == "ProcessSlackFileUploadJob"
          event = args.first
          event.is_a?(Hash) && @slack_ids.include?(event["user"])
        else
          (Array(args.first) & @urls).any?
        end
      end
    end

    def counts(jobs)
      return {} if jobs.empty?
      ids = jobs.map(&:id)
      EXECUTIONS.each_with_object({ "solid_queue_jobs" => ids.size }) do |kind, result|
        model = "SolidQueue::#{kind.camelize}Execution".constantize
        result[model.table_name] = model.where(job_id: ids).count
      end
    end

    def delete!(jobs)
      return {} if jobs.empty?
      ids = jobs.map(&:id)
      if SolidQueue::ClaimedExecution.where(job_id: ids).exists?
        raise Error.new("manual_review_required", 409)
      end
      EXECUTIONS.each_with_object({}) do |kind, result|
        model = "SolidQueue::#{kind.camelize}Execution".constantize
        result[model.table_name] = model.where(job_id: ids).delete_all
      end.merge("solid_queue_jobs" => SolidQueue::Job.where(id: ids).delete_all)
    end
  end
end
