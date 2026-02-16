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
      permitted = params.fetch(:user, params).permit(:quota_policy)
      permitted[:quota_policy] = nil if permitted[:quota_policy].blank?
      permitted
    end
  end
end
