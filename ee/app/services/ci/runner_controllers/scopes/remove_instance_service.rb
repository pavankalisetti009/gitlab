# frozen_string_literal: true

module Ci
  module RunnerControllers
    module Scopes
      class RemoveInstanceService
        attr_reader :runner_controller, :current_user

        def initialize(runner_controller:, current_user:)
          @runner_controller = runner_controller
          @current_user = current_user
        end

        def execute
          return error_no_permissions unless current_user.can_admin_all_resources?

          scoping = runner_controller.instance_level_scoping
          return ServiceResponse.success if scoping.nil?

          if scoping.destroy
            ServiceResponse.success
          else
            ServiceResponse.error(message: scoping.errors.full_messages.to_sentence)
          end
        end

        private

        def error_no_permissions
          ServiceResponse.error(
            message: 'Administrator permission is required to remove instance-level scope',
            reason: :forbidden
          )
        end
      end
    end
  end
end
