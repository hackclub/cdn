# frozen_string_literal: true

module QuotaHelper
  def quota_banner_for(user)
    quota_service = QuotaService.new(user)
    usage = quota_service.current_usage

    if quota_service.over_quota?
      # Danger banner when over quota
      render Primer::Beta::Flash.new(scheme: :danger) do
        <<~EOM
          You've exceeded your storage quota.
          You're using #{number_to_human_size(usage[:storage_used])} of #{number_to_human_size(usage[:storage_limit])}.#{' '}
          Please delete some files to continue uploading.
        EOM
      end
    elsif quota_service.at_warning?
      # Warning banner when >= 80% used
      render Primer::Beta::Flash.new(scheme: :warning, full: true) do
        plain "You're using #{usage[:percentage_used]}% of your storage quota "
        plain "(#{number_to_human_size(usage[:storage_used])} of #{number_to_human_size(usage[:storage_limit])}). "
        if usage[:policy] == "unverified"
          plain "Get verified at "
          a(href: "https://auth.hackclub.com", target: "_blank", rel: "noopener") { "auth.hackclub.com" }
          plain " to unlock 50GB of storage."
        end
      end
    end
    # Return nil if no warning needed
  end
end
