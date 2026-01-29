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

    private

    def set_user
      @user = User.find_by_public_id!(params[:id])
    end
  end
end
