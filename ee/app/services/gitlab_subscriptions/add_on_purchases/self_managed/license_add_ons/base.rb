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

          def quantity
            add_ons_info.sum(&:quantity)
          end
          strong_memoize_attr :quantity

          def active?
            quantity > 0
          end

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

          def add_ons_info
            return [] unless add_ons_in_license

            add_ons_in_license.map do |info_hash|
              attributes = info_hash.slice(:quantity, :started_on, :expires_on, :purchase_xid, :trial)

              Info.new(**attributes)
            end
          end
          strong_memoize_attr :add_ons_info

          def add_ons_in_license
            return [] unless restrictions

            restrictions.deep_symbolize_keys.dig(:add_on_products, name_in_license)
          end
          strong_memoize_attr :add_ons_in_license
        end
      end
    end
  end
end
