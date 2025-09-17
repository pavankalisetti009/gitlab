# frozen_string_literal: true

module Resolvers
  module WorkItems
    class AllowedStatusesResolver < Resolvers::WorkItems::BaseResolver
      type Types::WorkItems::StatusType.connection_type, null: true

      argument :name,
        type: GraphQL::Types::String,
        required: false,
        description: 'Filter statuses by name.'

      def resolve(name: nil)
        return [] unless work_item_status_feature_available?

        allowed_statuses_for_the_user(name)
      end

      private

      def work_item_status_feature_available?
        ::Feature.enabled?(:work_item_status_mvc2, current_user) &&
          License.feature_available?(:work_item_status)
      end

      def allowed_statuses_for_the_user(name = nil)
        group_ids = current_user&.authorized_groups&.top_level&.pluck(:id)
        return [] if group_ids.blank?

        custom_statuses = ::WorkItems::Statuses::Custom::Status.find_by_namespaces_with_partial_name(group_ids, name)
        system_defined_statuses = find_system_defined_statuses(name)
        result = custom_statuses.to_a.concat(system_defined_statuses)

        result
          .uniq { |status| status.name.downcase.strip }
          .sort_by { |status| status.name.downcase.strip }
      end

      def find_system_defined_statuses(name)
        if name.present?
          ::WorkItems::Statuses::SystemDefined::Status.find_by_name(name, partial_match: true)
        else
          ::WorkItems::Statuses::SystemDefined::Status.all
        end
      end
    end
  end
end
