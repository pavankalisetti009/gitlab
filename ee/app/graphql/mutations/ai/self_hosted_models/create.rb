# frozen_string_literal: true

module Mutations
  module Ai
    module SelfHostedModels
      class Create < Base
        graphql_name 'AiSelfHostedModelCreate'

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

          result = ::Ai::SelfHostedModels::CreateService.new(current_user, args).execute

          if result.success?
            {
              self_hosted_model: result.payload,
              errors: [] # Errors are rescued below
            }
          else
            {
              self_hosted_model: nil,
              errors: [result.message]
            }
          end
        end
      end
    end
  end
end
