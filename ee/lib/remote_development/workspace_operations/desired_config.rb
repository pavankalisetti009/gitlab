# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    class DesiredConfig
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations
      include ActiveModel::Serialization

      # @!attribute [rw] desired_config_array
      #   @return [Array]
      attribute :desired_config_array

      validates :desired_config_array, presence: true, json_schema: {
        filename: 'workspaces_kubernetes',
        detail_errors: true
      }
    end
  end
end
