# frozen_string_literal: true

module Resolvers
  module Notifications
    class TargetedMessageResolver < BaseResolver
      type [Types::Notifications::TargetedMessageType], null: true
      description 'Targeted messages for the namespace.'

      authorize :read_namespace

      alias_method :namespace, :object

      def resolve
        return unless namespace.owned_by?(current_user)

        ::Notifications::TargetedMessageNamespace
          .by_namespace_for_user(namespace, current_user)
          .map(&:targeted_message)
      end
    end
  end
end
