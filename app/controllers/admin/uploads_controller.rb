# frozen_string_literal: true

module Admin
  class UploadsController < ApplicationController
    before_action :set_upload

    def destroy
      filename = @upload.filename
      @upload.destroy!
      redirect_to admin_search_path, notice: "Upload #{filename} deleted."
    end

    private

    def set_upload
      @upload = Upload.find(params[:id])
    end
  end
end
