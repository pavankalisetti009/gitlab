# frozen_string_literal: true

module Users
  module MemberRoles
    class AssignService < BaseService
      attr_accessor :current_user, :params

      def initialize(current_user, params = {})
        @current_user = current_user
        @params = params
      end

      def execute
        unless current_user.can?(:admin_member_role)
          return ServiceResponse.error(message: 'Forbidden', reason: :forbidden)
        end

        unless Feature.enabled?(:custom_ability_read_admin_dashboard, current_user)
          return ServiceResponse.error(message: 'Not yet available', reason: :forbidden)
        end

        user_member_role = Users::UserMemberRole.create!(params)

        ServiceResponse.success(payload: { user_member_role: user_member_role })
      end
    end
  end
end
