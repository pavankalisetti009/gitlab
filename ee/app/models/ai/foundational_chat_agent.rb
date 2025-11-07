# frozen_string_literal: true

module Ai
  class FoundationalChatAgent
    include ActiveRecord::FixedItemsModel::Model
    include GlobalID::Identification
    include Ai::FoundationalChatAgentsDefinitions

    attribute :reference, :string
    attribute :name, :string
    attribute :description, :string
    attribute :version, :string

    validates :name, :reference, :description, presence: true

    def reference_with_version
      return reference if version.blank?

      "#{reference}/#{version}"
    end

    def workflow_definition
      reference_with_version
    end

    def to_global_id
      reference_with_version.sub('/', '-')
    end

    class << self
      def count
        all.size
      end

      def foundational_workflow_definition?(definition)
        all.any? { |agent| agent.workflow_definition == definition }
      end
    end
  end
end
