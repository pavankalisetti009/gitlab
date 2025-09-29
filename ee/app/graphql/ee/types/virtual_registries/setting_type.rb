# frozen_string_literal: true

# rubocop: disable Gitlab/EeOnlyClass -- EE only class with no CE equivalent
module EE
  module Types
    module VirtualRegistries
      class SettingType < ::Types::BaseObject
        graphql_name 'VirtualRegistriesSetting'

        description 'Root group level virtual registries settings'

        authorize :admin_virtual_registry

        field :enabled,
          GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether virtual registries are enabled for the group.'
      end
    end
  end
end
# rubocop: enable Gitlab/EeOnlyClass
