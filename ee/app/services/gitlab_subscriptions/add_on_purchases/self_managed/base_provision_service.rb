# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      class BaseProvisionService
        include ::Gitlab::Utils::StrongMemoize

        AddOnPurchaseSyncError = Class.new(StandardError)
        MethodNotImplementedError = Class.new(StandardError)

        def execute
          result = license_has_add_on? ? create_or_update_add_on_purchase : expire_prior_add_on_purchase

          unless result.success?
            raise AddOnPurchaseSyncError, "Error syncing subscription add-on purchases. Message: #{result[:message]}"
          end

          result
        rescue AddOnPurchaseSyncError => e
          Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e)

          ServiceResponse.error(message: e.message)
        end

        private

        def license_has_add_on?
          current_license&.online_cloud_license? && quantity > 0
        end

        def current_license
          License.current
        end
        strong_memoize_attr :current_license

        def license_restrictions
          current_license&.license&.restrictions
        end

        def empty_success_response
          ServiceResponse.success(payload: { add_on_purchase: nil })
        end

        def create_or_update_add_on_purchase
          service_class = if add_on_purchase
                            GitlabSubscriptions::AddOnPurchases::UpdateService
                          else
                            GitlabSubscriptions::AddOnPurchases::CreateService
                          end

          service_class.new(namespace, add_on, attributes).execute
        end

        def add_on_purchase
          GitlabSubscriptions::AddOnPurchase.find_by_namespace_and_add_on(namespace, add_on)
        end
        strong_memoize_attr :add_on_purchase

        def add_on
          GitlabSubscriptions::AddOn.find_or_create_by_name(name)
        end
        strong_memoize_attr :add_on

        def namespace
          nil # self-managed is unrelated to namespaces
        end

        def attributes
          {
            add_on_purchase: add_on_purchase,
            expires_on: expires_on,
            purchase_xid: purchase_xid,
            quantity: quantity
          }
        end

        def expire_prior_add_on_purchase
          return empty_success_response unless add_on_purchase

          GitlabSubscriptions::AddOnPurchases::SelfManaged::ExpireService.new(add_on_purchase).execute
        end

        def purchase_xid
          license_restrictions&.dig(:subscription_name)
        end

        def expires_on
          current_license&.block_changes_at || current_license&.expires_at
        end

        def quantity
          quantity_from_restrictions(license_restrictions) if license_restrictions
        end
        strong_memoize_attr :quantity

        def name
          raise MethodNotImplementedError
        end

        def quantity_from_restrictions(_)
          raise MethodNotImplementedError
        end
      end
    end
  end
end
