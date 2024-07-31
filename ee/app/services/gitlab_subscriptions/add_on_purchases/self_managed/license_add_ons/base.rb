# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module LicenseAddOns
        class Base
          include ::Gitlab::Utils::StrongMemoize

          MethodNotImplementedError = Class.new(StandardError)

          attr_reader :restrictions

          def initialize(restrictions)
            @restrictions = restrictions
          end

          def seat_count
            return 0 unless restrictions

            seat_count_on_license
          end
          strong_memoize_attr :seat_count

          def active?
            seat_count > 0
          end
          strong_memoize_attr :active?

          def add_on
            GitlabSubscriptions::AddOn.find_or_create_by_name(name)
          end
          strong_memoize_attr :add_on

          private

          def seat_count_on_license
            raise MethodNotImplementedError
          end

          def name
            raise MethodNotImplementedError
          end
        end
      end
    end
  end
end
