# frozen_string_literal: true

module Authz
  class Resource
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def permitted
      raise NotImplementedError
    end

    def permitted_to(permission, to_relation: true)
      ids = permitted.filter_map do |id, permissions|
        id if permission.in?(permissions || [])
      end
      to_relation ? scope.where(id: ids) : ids
    end
  end
end
