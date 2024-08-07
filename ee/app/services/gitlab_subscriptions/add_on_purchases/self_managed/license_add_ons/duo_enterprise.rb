# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module LicenseAddOns
        class DuoEnterprise < Base
          private

          def seat_count_on_license
            duo_enterprise_add_ons = restrictions.deep_symbolize_keys.dig(:add_on_products, :duo_enterprise)
            return 0 if duo_enterprise_add_ons.blank?

            duo_enterprise_add_ons.sum { |info| info[:quantity].to_i }
          end

          def name
            :duo_enterprise
          end
        end
      end
    end
  end
end
