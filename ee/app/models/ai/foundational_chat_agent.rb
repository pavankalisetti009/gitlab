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
    attribute :global_catalog_id, :integer

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
      def only_duo_chat_agent
        # The first agent must always Duo Chat Agent, this is covered through tests.
        # Duo chat has to be the first so it shows first in the UI
        [all[0]]
      end

      def except_duo_chat_agent
        # The first agent must always Duo Chat Agent, this is covered through tests.
        # Duo chat has to be the first so it shows first in the UI
        all.drop(1)
      end

      def count
        all.size
      end

      def foundational_workflow_definition?(definition)
        all.any? { |agent| agent.workflow_definition == definition }
      end

      def workflow_definitions
        all.map(&:workflow_definition)
      end

      def any_agents_with_reference?(definition)
        !!where(reference: definition).first
      end
    end
  end
end
