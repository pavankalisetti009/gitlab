# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module ProvisionServices
        class DuoEnterprise < BaseProvisionService
          private

          def quantity_from_restrictions(restrictions)
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
