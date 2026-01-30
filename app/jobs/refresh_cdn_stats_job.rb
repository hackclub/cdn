# frozen_string_literal: true

class RefreshCDNStatsJob < ApplicationJob
  queue_as :default

  def perform
    CDNStatsService.refresh_global_stats!
  end
end
