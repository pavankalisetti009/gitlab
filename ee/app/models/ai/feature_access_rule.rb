# frozen_string_literal: true

module Ai
  class FeatureAccessRule < ApplicationRecord
    include FeatureAccessRuleable

    self.table_name = 'ai_instance_accessible_entity_rules'

    belongs_to :through_namespace,
      class_name: 'Namespace',
      inverse_of: :accessible_ai_features_on_instance

    scope :accessible_for_user, ->(user, accessible_entity) {
      joins(
        "INNER JOIN members " \
          "ON members.source_id = ai_instance_accessible_entity_rules.through_namespace_id " \
          "AND members.source_type = 'Namespace'"
      ).where(accessible_entity: accessible_entity, members: { user_id: user.id })
    }

    class << self
      def duo_namespace_access_rules
        return {} unless ::Feature.enabled?(:duo_access_through_namespaces, :instance)

        group_by_through_namespace all
      end

      def duo_root_namespace_access_rules
        return {} unless ::Feature.enabled?(:duo_access_through_namespaces, :instance)

        group_by_through_namespace where(namespaces: { parent_id: nil, type: 'Group' })
      end

      def group_by_through_namespace(scope)
        scope
          .includes(:through_namespace)
          .order(:through_namespace_id, :accessible_entity)
          .group_by(&:through_namespace_id)
      end

      def duo_namespace_access_rules=(values)
        return unless ::Feature.enabled?(:duo_access_through_namespaces, :instance)

        values = values.map(&:deep_symbolize_keys).reject(&:blank?)

        delete_all

        return if values.empty?

        timestamp = Time.current
        rules = values.flat_map do |rule|
          features = rule[:features].reject(&:blank?)
          next [] if features.blank?

          features.map do |access_entity|
            new(
              through_namespace_id: rule.dig(:through_namespace, :id),
              accessible_entity: access_entity,
              created_at: timestamp,
              updated_at: timestamp
            )
          end
        end

        bulk_insert!(rules) if rules.any?
      end
    end
  end
end
