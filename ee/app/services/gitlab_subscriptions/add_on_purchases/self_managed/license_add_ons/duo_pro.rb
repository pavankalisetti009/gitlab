# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module LicenseAddOns
        class DuoPro < Base
          private

          def seat_count_on_license
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
