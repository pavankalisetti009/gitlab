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

        argument :ai_gateway_timeout_seconds, GraphQL::Types::Int,
          required: false,
          description: "Timeout for AI gateway request."

        argument :duo_agent_platform_service_url, String,
          required: false,
          description: 'URL for the local Duo Agent Platform service.'

        argument :duo_core_features_enabled, Boolean,
          required: false,
          validates: { allow_null: false },
          description: 'Indicates whether GitLab Duo Core features are enabled.'

        field :duo_settings, Types::Ai::DuoSettings::DuoSettingsType,
          null: false,
          description: 'GitLab Duo settings after mutation.'

        def resolve(**args)
          check_feature_available!(args)

          result = ::Ai::DuoSettings::UpdateService.new(permitted_params(args)).execute

          if result.error?
            duo_setting = ::Ai::Setting.instance # return existing setting
            errors = Array(result.errors)
          else
            duo_setting = result.payload
            errors = []
          end

          {
            duo_settings: duo_setting,
            errors: errors
          }
        end

        private

        def check_feature_available!(args)
          [:ai_gateway_url, :duo_agent_platform_service_url].each do |setting|
            if args.key?(setting) && !allowed_to_update?(:manage_self_hosted_models_settings)
              raise_resource_not_available_error!(setting)
            end
          end

          if args.key?(:ai_gateway_timeout_seconds) &&
              (!allowed_to_update?(:manage_instance_model_selection) ||
               !allowed_to_update?(:manage_self_hosted_models_settings))
            raise_resource_not_available_error!(:ai_gateway_timeout_seconds)
          end

          raise_resource_not_available_error!(:duo_core_features_enabled) if args.key?(:duo_core_features_enabled) &&
            !allowed_to_update?(:manage_duo_core_settings)
        end

        def allowed_to_update?(permission)
          Ability.allowed?(current_user, permission)
        end

        def raise_resource_not_available_error!(attribute)
          raise ::Gitlab::Graphql::Errors::ArgumentError,
            format(s_("You don't have permission to update the setting %{attribute}."), attribute: attribute)
        end

        def permitted_params(args)
          params = args.dup
          params[:ai_gateway_url] = params[:ai_gateway_url]&.chomp('/').presence if params.key?(:ai_gateway_url)
          if params.key?(:duo_agent_platform_service_url)
            params[:duo_agent_platform_service_url] = params[:duo_agent_platform_service_url]&.chomp('/').presence
          end

          params
        end
      end
    end
  end
end
