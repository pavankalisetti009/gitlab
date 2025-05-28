# frozen_string_literal: true

module Resolvers
  module WorkItems
    class LifecyclesResolver < Resolvers::WorkItems::BaseResolver
      type Types::WorkItems::LifecycleType.connection_type, null: true

      alias_method :namespace, :object

      def resolve
        return unless work_item_status_feature_available?
        return unless Ability.allowed?(current_user, :read_lifecycle, namespace)

        namespace.lifecycles
      end

      private

      def root_ancestor
        namespace.root_ancestor
      end
    end
  end
end
