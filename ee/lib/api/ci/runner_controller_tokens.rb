# frozen_string_literal: true

module API
  module Ci
    class RunnerControllerTokens < ::API::Base
      include ::API::PaginationParams

      feature_category :continuous_integration

      before do
        authenticated_as_admin!

        not_found! unless ::License.feature_available?(:ci_runner_controllers)
      end

      resource :runner_controllers do
        desc 'List runner controller tokens' do
          detail 'Get all tokens for a specific runner controller.'
          is_array true
          success Entities::Ci::RunnerControllerToken
          tags %w[runners]
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' }
          ]
        end
        params do
          requires :runner_controller_id, type: Integer, desc: 'ID of the runner controller'
          use :pagination
        end
        get ':runner_controller_id/tokens' do
          controller = ::Ci::RunnerController.find_by_id(params[:runner_controller_id])
          not_found! unless controller

          tokens = controller.tokens.active
          present paginate(tokens), with: Entities::Ci::RunnerControllerToken
        end

        desc 'Get single runner controller token' do
          detail 'Get a token for a specific runner controller by using the ID of the token.'
          success Entities::Ci::RunnerControllerToken
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not found' }
          ]
          tags %w[runner_controller_tokens]
        end
        params do
          requires :runner_controller_id, type: Integer, desc: 'ID of the runner controller'
          requires :id, type: Integer, desc: 'ID of the runner controller token'
        end
        get ':runner_controller_id/tokens/:id' do
          controller = ::Ci::RunnerController.find_by_id(params[:runner_controller_id])
          not_found! unless controller

          token = controller.tokens.active.find_by_id(params[:id])
          if token
            present token, with: Entities::Ci::RunnerControllerToken
          else
            not_found!
          end
        end

        desc 'Create a runner controller token' do
          detail 'Create a new token for a specific runner controller.'
          success Entities::Ci::RunnerControllerToken
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 400, message: 'Bad Request' },
            { code: 404, message: 'Not found' }
          ]
          tags %w[runner_controller_tokens]
        end
        params do
          requires :runner_controller_id, type: Integer, desc: 'ID of the runner controller'
          optional :description, type: String, desc: 'Description of the runner controller token',
            documentation: { example: 'Token for managing runner' }
        end
        post ':runner_controller_id/tokens' do
          controller = ::Ci::RunnerController.find_by_id(params[:runner_controller_id])
          not_found! unless controller

          token = controller.tokens.new(description: params[:description])

          if token.save
            present token, with: Entities::Ci::RunnerControllerTokenWithToken
          else
            bad_request!(token.errors.full_messages.to_sentence)
          end
        end

        desc 'Revoke a runner controller token' do
          detail 'Revoke a token for a specific runner controller.'
          success code: 204
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 400, message: 'Bad Request' },
            { code: 404, message: 'Not found' }
          ]
          tags %w[runner_controller_tokens]
        end
        params do
          requires :runner_controller_id, type: Integer, desc: 'ID of the runner controller'
          requires :id, type: Integer, desc: 'ID of the runner controller token'
        end
        delete ':runner_controller_id/tokens/:id' do
          controller = ::Ci::RunnerController.find_by_id(params[:runner_controller_id])
          not_found! unless controller

          token = controller.tokens.active.find_by_id(params[:id])
          not_found! unless token

          result = ::Ci::RunnerControllers::RevokeTokenService.new(token:, current_user:).execute

          if result.success?
            no_content!
          else
            bad_request!(result.message.to_sentence)
          end
        end

        desc 'Rotate a runner controller token' do
          detail 'Rotate an existing token for a specific runner controller.'
          success Entities::Ci::RunnerControllerTokenWithToken
          failure [
            { code: 403, message: 'Forbidden' },
            { code: 400, message: 'Bad Request' },
            { code: 404, message: 'Not found' }
          ]
          tags %w[runner_controller_tokens]
        end
        params do
          requires :runner_controller_id, type: Integer, desc: 'ID of the runner controller'
          requires :id, type: Integer, desc: 'ID of the runner controller token'
        end
        post ':runner_controller_id/tokens/:id/rotate' do
          controller = ::Ci::RunnerController.find_by_id(params[:runner_controller_id])
          not_found! unless controller

          token = controller.tokens.active.find_by_id(params[:id])
          not_found! unless token

          response = ::Ci::RunnerControllers::RotateTokenService.new(
            token: token,
            current_user: current_user
          ).execute

          if response.success?
            status :ok

            present response.payload, with: Entities::Ci::RunnerControllerTokenWithToken
          else
            bad_request!(response.message)
          end
        end
      end
    end
  end
end
