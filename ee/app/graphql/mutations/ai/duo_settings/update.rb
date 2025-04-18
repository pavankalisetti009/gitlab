# frozen_string_literal: true

module Mutations
  module Ai
    module DuoSettings
      class Update < BaseMutation
        graphql_name 'DuoSettingsUpdate'
        description "Updates GitLab Duo settings."

        argument :ai_gateway_url, String,
          required: false,
          description: 'URL for local AI gateway server.'

        field :ai_gateway_url, String,
          null: true,
          description: 'URL for local AI gateway server.'

        def resolve(**args)
          raise_resource_not_available_error! unless Ability.allowed?(current_user, :manage_self_hosted_models_settings)

          ai_gateway_url_cleaned = args[:ai_gateway_url]&.chomp('/')
          result = ::Ai::DuoSettings::UpdateService.new(ai_gateway_url: ai_gateway_url_cleaned.presence).execute

          if result.error?
            {
              ai_gateway_url: ::Ai::Setting.instance.ai_gateway_url, ## return existing AIGW url if update failed
              errors: Array(result.errors)
            }
          else
            { ai_gateway_url: result.payload.ai_gateway_url, errors: [] }
          end
        end
      end
    end
  end
end
