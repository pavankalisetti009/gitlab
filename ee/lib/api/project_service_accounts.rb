# frozen_string_literal: true

module API
  class ProjectServiceAccounts < ::API::Base
    include PaginationParams

    feature_category :user_management

    before do
      authenticate!
      not_found! unless Feature.enabled?(:allow_projects_to_create_service_accounts, user_project.root_ancestor)

      authorize! :admin_service_accounts, user_project
      set_current_organization
    end

    helpers do
      def service_account
        user_project.service_accounts.find_by_id(params[:user_id])
      end

      def validate_service_account
        not_found!('User') unless service_account
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end

    resource 'projects/:id', requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      resource :service_accounts do
        desc 'Create a service account user' do
          detail 'Create a service account user for a project'
          success Entities::ServiceAccount
          failure [
            { code: 400, message: '400 Bad request' },
            { code: 401, message: '401 Unauthorized' },
            { code: 403, message: '403 Forbidden' },
            { code: 404, message: '404 Project not found' }
          ]
          tags ['service_accounts']
        end

        params do
          optional :name, type: String, desc: 'Name of the user'
          optional :username, type: String, desc: 'Username of the user'
          optional :email, type: String, desc: 'Custom email address for the user'
        end

        post do
          organization_id = user_project.organization_id
          service_params = declared_params.merge({
            organization_id: organization_id,
            project_id: user_project.id
          })

          response = ::Namespaces::ServiceAccounts::CreateService
                       .new(current_user, service_params)
                       .execute

          if response.status == :success
            present response.payload[:user], with: Entities::ServiceAccount, current_user: current_user
          else
            bad_request!(response.message)
          end
        end

        desc 'Get list of service account users' do
          detail 'Get list of service account users for a project'
          success Entities::ServiceAccount
          failure [
            { code: 400, message: '400 Bad request' },
            { code: 401, message: '401 Unauthorized' },
            { code: 403, message: '403 Forbidden' },
            { code: 404, message: '404 Project not found' }
          ]
          tags ['service_accounts']
        end

        params do
          use :pagination
          optional :order_by, type: String, values: %w[id username], default: 'id',
            desc: 'Attribute to sort by'
          optional :sort, type: String, values: %w[asc desc], default: 'desc', desc: 'Order of sorting'
        end

        # rubocop: disable CodeReuse/ActiveRecord -- for reorder
        get do
          service_accounts = user_project.service_accounts

          service_accounts = service_accounts.reorder(params[:order_by] => params[:sort])

          present paginate_with_strategies(service_accounts), with: Entities::ServiceAccount, current_user: current_user
        end
        # rubocop: enable CodeReuse/ActiveRecord

        desc 'Delete a service account user' do
          detail 'Delete a service account user. Available only for project owners/maintainers and admins.'
          failure [
            { code: 400, message: '400 Bad request' },
            { code: 401, message: '401 Unauthorized' },
            { code: 403, message: '403 Forbidden' },
            { code: 404, message: '404 Project not found' }
          ]
          tags ['service_accounts']
          success code: 204
        end

        params do
          requires :user_id, type: Integer, desc: 'The ID of the service account user'
          optional :hard_delete, type: Boolean, desc: "Whether to remove a user's contributions"
        end

        delete ":user_id" do
          validate_service_account

          delete_params = declared_params(include_missing: false)

          destroy_conditionally!(service_account) do
            ::Namespaces::ServiceAccounts::DeleteService
              .new(current_user, service_account)
              .execute(delete_params)
          end
        end

        desc 'Update a service account user' do
          detail 'Update a service account user'
          success Entities::ServiceAccount
          failure [
            { code: 400, message: '400 Bad request' },
            { code: 401, message: '401 Unauthorized' },
            { code: 403, message: '403 Forbidden' },
            { code: 404, message: '404 User not found' }
          ]
          tags ['service_accounts']
        end

        params do
          requires :user_id, type: Integer, desc: 'The ID of the service account user'
          optional :name, type: String, desc: 'Name of the user'
          optional :username, type: String, desc: 'Username of the user'
          optional :email, type: String, desc: 'Custom email address for the user'
        end

        patch ":user_id" do
          validate_service_account

          update_params = declared_params(include_missing: false).merge({ project_id: user_project.id })

          response = ::Namespaces::ServiceAccounts::UpdateService
                       .new(current_user, service_account, update_params)
                       .execute

          if response.success?
            present response.payload[:user], with: Entities::ServiceAccount, current_user: current_user
          else
            render_api_error!(response.message, response.reason)
          end
        end
      end
    end
  end
end
