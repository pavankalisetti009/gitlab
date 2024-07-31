# frozen_string_literal: true

module Resolvers
  module GitlabSubscriptions
    class AddOnPurchasesResolver < BaseResolver
      type [Types::GitlabSubscriptions::AddOnPurchaseType], null: true

      argument :namespace_id,
        type: ::Types::GlobalIDType[::Namespace],
        required: false,
        description: 'ID of namespace that the add-ons were purchased for.'

      def resolve(namespace_id: nil)
        ::GitlabSubscriptions::AddOnPurchase.active.by_namespace(namespace_id&.model_id)
      end
    end
  end
end
