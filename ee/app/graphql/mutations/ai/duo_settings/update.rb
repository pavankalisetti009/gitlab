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

        argument :duo_core_features_enabled, Boolean,
          required: false,
          validates: { allow_null: false },
          description: 'Indicates whether GitLab Duo Core features are enabled.'

        field :ai_gateway_url, String,
          null: true,
          description: 'URL for local AI gateway server.'

        field :duo_core_features_enabled, Boolean,
          null: true,
          description: 'Indicates whether GitLab Duo Core features are enabled.',
          experiment: { milestone: '18.0' }

        def resolve(**args)
          check_feature_available!(args)

          result = ::Ai::DuoSettings::UpdateService.new(permitted_params(args)).execute

          if result.error?
            setting = ::Ai::Setting.instance # return existing setting
            errors = Array(result.errors)
          else
            setting = result.payload
            errors = []
          end

          {
            ai_gateway_url: authorized_read(:read_self_hosted_models_settings, setting, setting.ai_gateway_url),
            duo_core_features_enabled: authorized_read(
              :read_duo_core_settings,
              setting,
              setting.duo_nano_features_enabled?
            ),
            errors: errors
          }
        end

        private

        def check_feature_available!(args)
          raise_resource_not_available_error!(:ai_gateway_url) if args.key?(:ai_gateway_url) &&
            !allowed_to_update?(:manage_self_hosted_models_settings)

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

          # Customer facing name has changed since the feature development started. The customer facing name will be
          # different from the internal name until a complete rename will be done. See this thread for more info:
          # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/187565#note_2448050894
          if params.key?(:duo_core_features_enabled)
            params[:duo_nano_features_enabled] = params.delete(:duo_core_features_enabled)
          end

          params
        end

        def authorized_read(permission, setting, attribute)
          Ability.allowed?(current_user, permission, setting) ? attribute : nil
        end
      end
    end
  end
end
