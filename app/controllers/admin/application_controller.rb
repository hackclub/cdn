module Admin
  class ApplicationController < ::ApplicationController
    before_action :require_admin!

    private

    def require_admin!
      redirect_to(
        root_path,
        alert: "You need to be an admin to access this page."
      ) unless current_user&.is_admin?
    end
  end
end