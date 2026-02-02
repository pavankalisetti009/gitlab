# frozen_string_literal: true

module API
  module Ci
    class RunnerControllers < ::API::Base
      include ::API::PaginationParams

      feature_category :continuous_integration
      before do
        authenticated_as_admin!

        not_found! unless ::License.feature_available?(:ci_runner_controllers)
      end

      resource :runner_controllers do
        desc 'List runner controllers' do
          detail 'Get all runner controllers.'
          is_array true
          success Entities::Ci::RunnerController
          tags %w[runners]
          failure [
            { code: 403, message: 'Forbidden' }
          ]
        end
        params do
          use :pagination
        end
        get do
          controllers = ::Ci::RunnerController.all

          present paginate(controllers), with: Entities::Ci::RunnerController
        end

        desc 'Get single runner controller' do
          detail 'Get a runner controller by using the ID of the controller.'
          success Entities::Ci::RunnerController
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' }
          ]
          tags %w[runner_controllers]
        end
        params do
          requires :id, type: Integer, desc: 'ID of the runner controller'
        end
        get ':id' do
          controller = ::Ci::RunnerController.find_by_id(params[:id])

          if controller
            present controller, with: Entities::Ci::RunnerController
          else
            not_found!
          end
        end

        desc 'Register a runner controller' do
          detail 'Register a new runner controller.'
          success Entities::Ci::RunnerController
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 400, message: 'Bad Request' }
          ]
          tags %w[runner_controllers]
        end
        params do
          optional :description, type: String, desc: 'Description of the runner controller',
            documentation: { example: 'Controller for managing runner' }
          optional :state, type: String, values: ::Ci::RunnerController.states.keys, default: 'disabled',
            desc: 'State of the runner controller (disabled, enabled, dry_run)',
            documentation: { example: 'enabled' }
        end
        post do
          controller = ::Ci::RunnerController.new(
            description: params[:description],
            state: params[:state]
          )

          if controller.save
            present controller, with: Entities::Ci::RunnerController
          else
            bad_request!(controller.errors.full_messages.to_sentence)
          end
        end

        desc 'Update a runner controller' do
          detail 'Update a runner controller by using the ID of the controller.'
          success Entities::Ci::RunnerController
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' },
            { code: 400, message: 'Bad Request' }
          ]
          tags %w[runner_controllers]
        end
        params do
          requires :id, type: Integer, desc: 'ID of the runner controller'
          optional :description, type: String, desc: 'Description of the runner controller',
            documentation: { example: 'Controller for managing runner' }
          optional :state, type: String, values: ::Ci::RunnerController.states.keys,
            desc: 'State of the runner controller (disabled, enabled, dry_run)',
            documentation: { example: 'dry_run' }
        end
        put ':id' do
          controller = ::Ci::RunnerController.find_by_id(params[:id])

          not_found! unless controller

          update_params = params.slice(:description, :state)

          if controller.update(update_params)
            present controller, with: Entities::Ci::RunnerController
          else
            bad_request!(controller.errors.full_messages.to_sentence)
          end
        end

        desc 'Delete a runner controller' do
          detail 'Delete a runner controller by using the ID of the controller.'
          success Entities::Ci::RunnerController
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' }
          ]
          tags %w[runner_controllers]
        end
        params do
          requires :id, type: Integer, desc: 'ID of the runner controller'
        end
        delete ':id' do
          controller = ::Ci::RunnerController.find_by_id(params[:id])

          not_found! unless controller

          destroy_conditionally!(controller) do
            result = controller.destroy

            unless result
              error_message = controller.errors.full_messages.to_sentence
              bad_request!("Failed to delete runner controller. #{error_message}")
            end
          end
        end
      end
    end
  end
end
