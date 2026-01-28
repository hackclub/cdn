class StaticPagesController < ApplicationController
  skip_before_action :require_authentication!, only: [:home]

  def home
  end
end
