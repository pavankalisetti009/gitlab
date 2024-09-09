# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module GitlabCom
      class ProvisionService
        extend ::Gitlab::Utils::Override

        DUO_PRO = :duo_pro
        DUO_ENTERPRISE = :duo_enterprise
        ADD_ON_MAPPING = { duo_pro: :code_suggestions }.freeze

        attr_accessor :add_on_products, :namespace

        def initialize(namespace, add_on_products = [])
          @namespace = namespace
          @add_on_products = consolidate(add_on_products.deep_symbolize_keys)
        end

        def execute
          responses = add_on_products.map { |name, products| create_or_update(name, products.first) }

          if responses.any?(&:success?)
            GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker.perform_async(namespace.id)
          end

          if responses.all?(&:success?)
            ServiceResponse.success(**service_response(responses))
          else
            ServiceResponse.error(**service_response(responses))
          end
        end

        private

        def consolidate(add_on_products)
          add_on_products.each_with_object({}) do |(key, value), hash|
            next unless value.presence
            next if key == DUO_PRO && add_on_products[DUO_ENTERPRISE].present?

            hash[key] = value
          end
        end

        def create_or_update(name, product)
          add_on_purchase = add_on_purchase(name)
          add_on = add_on(name)
          attributes = attributes(product).merge(add_on_purchase: add_on_purchase)

          service_class = if add_on_purchase
                            GitlabSubscriptions::AddOnPurchases::GitlabCom::UpdateService
                          else
                            GitlabSubscriptions::AddOnPurchases::CreateService
                          end

          service_class.new(namespace, add_on, attributes).execute
        end

        def attributes(product)
          {
            quantity: product[:quantity],
            started_on: product[:started_on],
            expires_on: product[:expires_on],
            purchase_xid: product[:purchase_xid],
            trial: product[:trial]
          }
        end

        def add_on(name)
          GitlabSubscriptions::AddOn.find_or_create_by_name(ADD_ON_MAPPING[name] || name)
        end

        def add_on_purchase(name)
          if name == DUO_PRO || name == DUO_ENTERPRISE
            GitlabSubscriptions::Duo.any_add_on_purchase_for_namespace(namespace.id)
          else
            GitlabSubscriptions::AddOnPurchase.by_namespace(namespace).by_add_on_name(name).presence
          end
        end

        def service_response(responses)
          {
            message: responses.filter_map(&:message).join(" ").presence,
            payload: { add_on_purchases: responses.filter_map(&:payload).filter_map(&:values).flatten }
          }
        end
      end
    end
  end
end
