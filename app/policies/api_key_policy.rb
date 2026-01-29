# frozen_string_literal: true

class APIKeyPolicy < ApplicationPolicy
  def index? = true
  def create? = true

  def destroy?
    user.is_admin? || record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.is_admin? ? scope.all : scope.where(user: user)
    end
  end
end
