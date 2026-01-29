class StaticPagesController < ApplicationController
  skip_before_action :require_authentication!, only: [:home]

  def home
    @flavor_text = FlavorTextService.new(user: current_user).generate
    if signed_in?
      @user_stats = CDNStatsService.user_stats(current_user)
    else
      @global_stats = CDNStatsService.global_stats
    end
  end
end
