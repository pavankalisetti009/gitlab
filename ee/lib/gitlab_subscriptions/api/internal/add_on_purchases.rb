# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class AddOnPurchases < ::API::Base
        feature_category :"add-on_provisioning"
        urgency :low

        namespace :internal do
          namespace :gitlab_subscriptions do
            resource :namespaces do
              before do
                @namespace = find_namespace(params[:id])
                not_found!('Namespace') unless @namespace
              end

              desc 'Create multiple add-on purchases for the namespace' do
                detail 'Creates multiple subscription add-on records for the given namespace'
                success ::EE::API::Entities::GitlabSubscriptions::AddOnPurchase
                failure [
                  { code: 400, message: 'Bad request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' }
                ]
              end

              helpers do
                params :add_on do
                  requires :started_on, type: Date, desc: 'The date when purchase takes effect'
                  requires :expires_on, type: Date, desc: 'The date when purchase expires on'
                  requires :quantity, type: Integer, desc: 'The quantity of the purchase'
                  requires :purchase_xid, type: String,
                    desc: 'The purchase identifier  (example: the subscription name)'
                  optional :trial, type: Boolean, default: false, desc: 'Whether the add-on is a trial'
                end
              end

              params do
                requires :add_on_purchases, type: Hash, desc: 'Hash of add-on names to list of purchase details' do
                  optional :duo_pro, type: Array, desc: 'List of Duo Pro add-on purchases' do
                    use :add_on
                  end
                  optional :duo_enterprise, type: Array, desc: 'List of Duo Enterprise add-on purchases' do
                    use :add_on
                  end
                  optional :product_analytics, type: Array, desc: 'List of product analytics add-on purchases' do
                    use :add_on
                  end
                end
              end

              post ":id/subscription_add_on_purchases" do
                result = ::GitlabSubscriptions::AddOnPurchases::GitlabCom::ProvisionService.new(
                  @namespace,
                  declared_params[:add_on_purchases]
                ).execute

                add_on_purchases = result[:add_on_purchases]

                if result.success?
                  present add_on_purchases, with: ::EE::API::Entities::GitlabSubscriptions::AddOnPurchase
                elsif !add_on_purchases || add_on_purchases.empty?
                  bad_request!(result[:message])
                else
                  render_validation_error!(result[:add_on_purchases])
                end
              end
            end
          end
        end
      end
    end
  end
end
