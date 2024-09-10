# frozen_string_literal: true

module Mutations
  module Ai
    module SelfHostedModels
      class Update < Base
        graphql_name 'AiSelfHostedModelUpdate'
        description "Updates a self-hosted model."

        argument :id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: true,
          description: 'Global ID of the self-hosted model to update.'

        argument :name, GraphQL::Types::String,
          required: true,
          description: 'Deployment name of the self-hosted model.'

        argument :model, ::Types::Ai::SelfHostedModels::AcceptedModelsEnum,
          required: true,
          description: 'AI model deployed.'

        argument :endpoint, GraphQL::Types::String,
          required: true,
          description: 'Endpoint of the self-hosted model.'

        argument :api_token, GraphQL::Types::String,
          required: false,
          description: 'API token to access the self-hosted model, if any.'

        def resolve(**args)
          check_feature_access!

          model = find_object(id: args.delete(:id))

          result = ::Ai::SelfHostedModels::UpdateService.new(model, current_user, args).execute

          {
            self_hosted_model: result.success? ? result.payload : nil,
            errors: result.error? ? Array.wrap(result.errors) : []
          }
        end

        private

        def find_object(id:)
          GitlabSchema.object_from_id(id, expected_type: ::Ai::SelfHostedModel).sync
        end
      end
    end
  end
end
