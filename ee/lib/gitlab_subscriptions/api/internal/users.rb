# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class Users < ::API::Base
        feature_category :subscription_management
        urgency :low

        namespace :internal do
          namespace :gitlab_subscriptions do
            resource :users do
              desc 'Get a single user' do
                success Entities::Internal::User
              end

              params do
                requires :id, type: Integer, desc: 'The ID of the user'
              end

              get ':id' do
                user = User.find_by_id(params[:id])

                not_found!('User') unless user

                present user, with: Entities::Internal::User
              end
            end

            resource :namespaces, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
              before do
                @namespace = find_namespace(params[:namespace_id])

                not_found!('Namespace') unless @namespace.present?
              end

              desc 'Returns the permissions that the user has in this namespace' do
                success Entities::Internal::Namespaces::UserPermissions
              end
              get ":namespace_id/user_permissions/:user_id" do
                user = User.find_by_id(params[:user_id])

                not_found!('User') unless user.present?

                present :edit_billing, user.can?(:edit_billing, @namespace)
              end
            end
          end
        end
      end
    end
  end
end
