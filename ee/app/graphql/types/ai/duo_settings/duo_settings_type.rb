# frozen_string_literal: true

module Types
  module Ai
    module DuoSettings
      class DuoSettingsType < ::Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- already authorized through resolver
        graphql_name 'DuoSettings'
        description 'GitLab Duo settings'

        # rubocop: disable GraphQL/ExtractType -- no value for now
        field :ai_gateway_url, String,
          null: true,
          description: 'URL for local AI gateway server.',
          authorize: :read_self_hosted_models_settings,
          experiment: { milestone: '17.9' }

        field :ai_gateway_timeout_seconds, GraphQL::Types::Int,
          null: true,
          description: 'Timeout in seconds for requests to the AI gateway server.',
          authorize: :read_self_hosted_models_settings
        # rubocop: enable GraphQL/ExtractType

        field :duo_agent_platform_service_url, String,
          null: true,
          description: 'URL for local Duo Agent Platform service.',
          authorize: :read_self_hosted_models_settings,
          experiment: { milestone: '18.4' }

        field :updated_at, Types::TimeType,
          null: false,
          description: 'Timestamp of last GitLab Duo setting update.',
          experiment: { milestone: '17.9' }

        field :duo_core_features_enabled, Boolean, # rubocop:disable GraphQL/ExtractType -- no need to extract into a separate type
          null: true, # has to allow null in case authorization fails
          method: :duo_core_features_enabled?,
          description: 'Indicates whether GitLab Duo Core features are enabled.',
          authorize: :read_duo_core_settings,
          experiment: { milestone: '18.0' }

        # rubocop: disable GraphQL/ExtractType -- suggestion does not make sense
        field :minimum_access_level_execute, Integer,
          null: true,
          description: 'Minimum access level required to execute Duo Agent Platform. ' \
            'Returns `null` if `dap_instance_customizable_permissions` feature flag is disabled.',
          authorize: :read_ai_role_based_permission_settings,
          experiment: { milestone: '18.7' }

        field :minimum_access_level_manage, Integer,
          null: true,
          description: 'Minimum access level required to manage Duo Agent Platform. ' \
            'Returns `null` if `dap_instance_customizable_permissions` feature flag is disabled.',
          authorize: :read_ai_role_based_permission_settings,
          experiment: { milestone: '18.7' }

        field :minimum_access_level_enable_on_projects, Integer,
          null: true,
          description: 'Minimum access level required to enable Duo Agent Platform. ' \
            'Returns `null` if `dap_instance_customizable_permissions` feature flag is disabled.',
          authorize: :read_ai_role_based_permission_settings,
          experiment: { milestone: '18.7' }
        # rubocop: enable GraphQL/ExtractType
      end
    end
  end
end
