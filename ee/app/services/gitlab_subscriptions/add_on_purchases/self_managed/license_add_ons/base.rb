# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module LicenseAddOns
        class Base
          extend ::Gitlab::Utils::Override
          include ::Gitlab::Utils::StrongMemoize

          MethodNotImplementedError = Class.new(StandardError)

          attr_reader :restrictions

          def initialize(restrictions)
            @restrictions = restrictions
          end

          def seat_count
            return 0 unless restrictions

            add_on_info = restrictions.deep_symbolize_keys.dig(:add_on_products, name_in_license)
            return 0 if add_on_info.blank?

            add_on_info.sum { |info| info[:quantity].to_i }
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

          def name
            raise MethodNotImplementedError
          end

          # needed to handle code_suggestions => duo_pro naming difference
          def name_in_license
            name
          end
        end
      end
    end
  end
end
