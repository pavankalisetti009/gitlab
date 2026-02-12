# frozen_string_literal: true

module Ci
  module RunnerControllers
    module Scopes
      class AddInstanceService
        attr_reader :runner_controller, :current_user

        def initialize(runner_controller:, current_user:)
          @runner_controller = runner_controller
          @current_user = current_user
        end

        def execute
          return error_no_permissions unless current_user.can_admin_all_resources?
          return error_already_exists if runner_controller.instance_level_scoping.present?

          scoping = runner_controller.build_instance_level_scoping

          if scoping.save
            ServiceResponse.success(payload: scoping)
          else
            ServiceResponse.error(message: scoping.errors.full_messages.to_sentence)
          end
        end

        private

        def error_no_permissions
          ServiceResponse.error(
            message: 'Administrator permission is required to add instance-level scope',
            reason: :forbidden
          )
        end

        def error_already_exists
          ServiceResponse.error(
            message: 'Instance-level scope already exists for this runner controller',
            reason: :conflict
          )
        end
      end
    end
  end
end
