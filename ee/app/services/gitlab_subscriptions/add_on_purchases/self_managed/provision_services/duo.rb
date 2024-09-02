# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module ProvisionServices
        class Duo < Base
          LICENSE_ADD_ONS_ORDERED_BY_PRECEDENCE = [
            LicenseAddOns::DuoEnterprise,
            LicenseAddOns::DuoPro
          ].freeze

          private

          override :add_on_purchase
          def add_on_purchase
            GitlabSubscriptions::AddOnPurchase.find_by_namespace_and_add_on(
              namespace,
              license_add_ons.map(&:add_on)
            )
          end
          strong_memoize_attr :add_on_purchase

          override :add_on
          def add_on
            license_add_on&.add_on
          end

          override :quantity
          def quantity
            license_add_on&.quantity
          end

          def license_add_ons
            LICENSE_ADD_ONS_ORDERED_BY_PRECEDENCE.map { |license_add_on| license_add_on.new(license_restrictions) }
          end
          strong_memoize_attr :license_add_ons

          def license_add_on
            license_add_ons.find(&:active?)
          end
          strong_memoize_attr :license_add_on
        end
      end
    end
  end
end
