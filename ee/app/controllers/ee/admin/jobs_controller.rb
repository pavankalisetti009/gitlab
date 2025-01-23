# frozen_string_literal: true

module EE
  module Admin
    module JobsController
      extend ::Gitlab::Utils::Override

      private

      override :authenticate_admin!
      def authenticate_admin!
        return if action_name == 'index' && can?(current_user, :read_admin_cicd)

        super
      end
    end
  end
end
