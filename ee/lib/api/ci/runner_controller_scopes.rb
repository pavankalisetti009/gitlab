# frozen_string_literal: true

module API
  module Ci
    class RunnerControllerScopes < ::API::Base
      feature_category :continuous_integration

      before do
        authenticated_as_admin!

        not_found! unless ::License.feature_available?(:ci_runner_controllers)
      end

      helpers do
        def find_runner_controller!
          controller = ::Ci::RunnerController.find_by_id(params[:id])
          not_found! unless controller
          controller
        end
      end

      resource :runner_controllers do
        desc 'List runner controller scopes' do
          detail 'Get all scopes for a specific runner controller.'
          success code: 200
          tags %w[runner_controllers]
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' }
          ]
        end
        params do
          requires :id, type: Integer, desc: 'ID of the runner controller'
        end
        get ':id/scopes' do
          controller = find_runner_controller!

          instance_level_scopings = [controller.instance_level_scoping].compact

          {
            instance_level_scopings: instance_level_scopings.map do |scoping|
              Entities::Ci::RunnerControllerInstanceLevelScoping.represent(scoping)
            end
          }
        end

        desc 'Add instance-level scope' do
          detail 'Add an instance-level scope to a runner controller.'
          success Entities::Ci::RunnerControllerInstanceLevelScoping
          tags %w[runner_controllers]
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' },
            { code: 409, message: 'Conflict' }
          ]
        end
        params do
          requires :id, type: Integer, desc: 'ID of the runner controller'
        end
        post ':id/scopes/instance' do
          controller = find_runner_controller!

          result = ::Ci::RunnerControllers::Scopes::AddInstanceService.new(
            runner_controller: controller,
            current_user: current_user
          ).execute

          if result.success?
            present result.payload, with: Entities::Ci::RunnerControllerInstanceLevelScoping
          elsif result.reason == :conflict
            conflict!(result.message)
          else
            bad_request!(result.message)
          end
        end

        desc 'Remove instance-level scope' do
          detail 'Remove an instance-level scope from a runner controller.'
          success code: 204
          tags %w[runner_controllers]
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' }
          ]
        end
        params do
          requires :id, type: Integer, desc: 'ID of the runner controller'
        end
        delete ':id/scopes/instance' do
          controller = find_runner_controller!

          result = ::Ci::RunnerControllers::Scopes::RemoveInstanceService.new(
            runner_controller: controller,
            current_user: current_user
          ).execute

          if result.success?
            no_content!
          else
            bad_request!(result.message)
          end
        end
      end
    end
  end
end
