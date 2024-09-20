# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class DuoSeatsMetric < GenericMetric
          value do
            {
              pro: duo_seats_data(:pro),
              enterprise: duo_seats_data(:enterprise)
            }
          end

          private

          def duo_seats_data(type)
            purchases = case type
                        when :pro
                          GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro
                        when :enterprise
                          GitlabSubscriptions::AddOnPurchase.for_duo_enterprise
                        end

            active_duo = purchases.active.first

            {
              seats: active_duo&.quantity,
              assigned: active_duo&.assigned_users&.count
            }
          end
        end
      end
    end
  end
end
