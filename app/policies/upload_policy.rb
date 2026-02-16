# frozen_string_literal: true

class UploadPolicy < ApplicationPolicy
  def destroy?
    # Users can delete their own uploads, admins can delete any upload
    user.is_admin? || record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.is_admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end
