# frozen_string_literal: true

module EE
  module Organizations
    module Groups
      module TransferService
        extend ::Gitlab::Utils::Override
        include ::Gitlab::Utils::StrongMemoize

        override :perform_transfer
        def perform_transfer
          super

          transfer_subscriptions
        end

        private

        def transfer_subscriptions
          update_organization_id_for(::GitlabSubscriptions::AddOnPurchase) { |relation| relation.by_namespace(group) }
          update_organization_id_for(::GitlabSubscriptions::SeatAssignment) { |relation| relation.by_namespace(group) }

          update_organization_id_for(::GitlabSubscriptions::UserAddOnAssignment) do |relation|
            relation.for_add_on_purchases(add_on_purchases_relation)
          end
        end

        def add_on_purchases_relation
          ::GitlabSubscriptions::AddOnPurchase.by_namespace(group)
        end
        strong_memoize_attr :add_on_purchases_relation
      end
    end
  end
end
