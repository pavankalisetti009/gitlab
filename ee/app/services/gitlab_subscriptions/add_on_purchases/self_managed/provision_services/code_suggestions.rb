# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module ProvisionServices
        class CodeSuggestions < BaseProvisionService
          private

          def quantity_from_restrictions(restrictions)
            restrictions[:code_suggestions_seat_count].to_i
          end

          def name
            :code_suggestions
          end
        end
      end
    end
  end
end
