# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :set_user

    def show
    end

    def update
      @user.update!(user_params)
      redirect_to admin_user_path(@user), notice: "User updated."
    end

    def destroy
      @user.destroy!
      redirect_to admin_search_path, notice: "User #{@user.name || @user.email} deleted."
    end

    private

    def set_user
      @user = User.find_by_public_id!(params[:id])
    end

    def user_params
      params.require(:user).permit(:quota_policy).tap do |p|
        # Normalize empty string to nil for auto-detect
        p[:quota_policy] = nil if p[:quota_policy].blank?
      end
    end
  end
end
