# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :set_user

    def show
    end

    def destroy
      @user.destroy!
      redirect_to admin_search_path, notice: "User #{@user.name || @user.email} deleted."
    end

    def set_quota
      quota_policy = params[:quota_policy]

      # Empty string means auto-detect (clear override)
      if quota_policy.blank?
        @user.update!(quota_policy: nil)
        redirect_to admin_user_path(@user), notice: "Quota policy cleared. Will auto-detect via HCA."
        return
      end

      unless %w[verified functionally_unlimited].include?(quota_policy)
        redirect_to admin_user_path(@user), alert: "Invalid quota policy."
        return
      end

      @user.update!(quota_policy: quota_policy)
      redirect_to admin_user_path(@user), notice: "Quota policy set to #{quota_policy.humanize}."
    end

    private

    def set_user
      @user = User.find_by_public_id!(params[:id])
    end
  end
end
