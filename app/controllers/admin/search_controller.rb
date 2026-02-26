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
      by_search = Upload.search(query)
      by_url = Upload.where("original_url ILIKE ?", "%#{Upload.sanitize_sql_like(query)}%")
      Upload.where(id: by_search.select(:id)).or(Upload.where(id: by_url.select(:id)))
            .includes(:blob, :user).order(created_at: :desc).limit(50)
    end
  end
end
