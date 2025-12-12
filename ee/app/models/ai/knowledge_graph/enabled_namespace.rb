# frozen_string_literal: true

module Ai
  module KnowledgeGraph
    class EnabledNamespace < ApplicationRecord
      self.table_name = 'knowledge_graph_enabled_namespaces'

      belongs_to :namespace, class_name: 'Namespace',
        foreign_key: :root_namespace_id, inverse_of: :knowledge_graph_enabled_namespace

      validate :only_root_namespaces_can_be_indexed

      scope :for_root_namespace_id, ->(root_namespace_id) { where(root_namespace_id: root_namespace_id) }
      scope :recent, -> { order(id: :desc) }
      scope :with_limit, ->(maximum) { limit(maximum) }

      private

      def only_root_namespaces_can_be_indexed
        return if namespace&.root?

        errors.add(:root_namespace_id, 'Only root namespaces can be indexed')
      end
    end
  end
end
