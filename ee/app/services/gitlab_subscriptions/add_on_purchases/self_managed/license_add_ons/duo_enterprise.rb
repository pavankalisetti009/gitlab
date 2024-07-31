# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module LicenseAddOns
        class DuoEnterprise < Base
          private

          def seat_count_on_license
            restrictions.deep_symbolize_keys.dig(:duo_enterprise, :quantity).to_i
          end

          def name
            :duo_enterprise
          end
        end
      end
    end
  end
end
