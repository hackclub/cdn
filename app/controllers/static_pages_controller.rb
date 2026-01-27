class StaticPagesController < ApplicationController
  skip_before_action :require_authentication!, only: [:login]

  def home
  end

  def login
    redirect_to home_path if signed_in?
  end
end
