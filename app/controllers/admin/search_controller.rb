# frozen_string_literal: true

module Admin
  class SearchController < ApplicationController
    def index
      @query = params[:q].to_s.strip
      @type = params[:type] || "all"
      return if @query.blank?

      @users = search_users(@query) if @type.in?(%w[all users])
      @uploads = search_uploads(@query) if @type.in?(%w[all uploads])
    end

    private

    def search_users(query)
      User.search(query).limit(20)
    end

    def search_uploads(query)
      Upload.search(query).includes(:blob, :user).order(created_at: :desc).limit(50)
    end
  end
end
