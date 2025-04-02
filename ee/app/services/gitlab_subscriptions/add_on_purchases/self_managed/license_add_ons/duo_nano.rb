# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module LicenseAddOns
        class DuoNano < Base
          private

          override :name
          def name
            :duo_nano
          end
        end
      end
    end
  end
end
