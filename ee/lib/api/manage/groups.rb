# frozen_string_literal: true

module API
  module Manage
    class Groups < ::API::Base
      feature_category :system_access

      include PaginationParams

      before do
        not_found! unless Feature.enabled?(:manage_pat_by_group_owners_ready, user_group)

        authenticate!
        authorize! :admin_group, user_group
      end

      helpers ::API::Helpers::PersonalAccessTokensHelpers

      helpers do
        def users
          user_group.enterprise_users
        end

        def ssh_keys_finder_params
          declared(params, include_missing: false).merge({ users: users, key_type: 'ssh' })
        end

        def pat_finder_params
          declared(params,
            include_missing: false).merge({ users: users, impersonation: false, sort: 'id_desc', owner_type: 'human' })
        end
      end

      namespace 'groups/:id/manage' do
        params do
          requires :id, type: String
        end

        resources :personal_access_tokens do
          params do
            use :access_token_params
            use :pagination
          end

          desc 'Get Personal access tokens' do
            detail 'This feature was introduced in GitLab 17.8.'
          end
          get do
            tokens = PersonalAccessTokensFinder.new(pat_finder_params).execute.preload_users

            present paginate(tokens), with: Entities::PersonalAccessToken
          end
        end

        resources :ssh_keys do
          params do
            optional :created_before, type: DateTime, desc: 'Filter ssh keys which were created before given datetime',
              documentation: { example: '2022-01-01' }
            optional :created_after, type: DateTime, desc: 'Filter ssh keys which were created after given datetime',
              documentation: { example: '2021-01-01' }
            optional :expires_before, type: DateTime, desc: 'Filter ssh keys which were created before given datetime',
              documentation: { example: '2022-01-01' }
            optional :expires_after, type: DateTime, desc: 'Filter ssh keys which were created after given datetime',
              documentation: { example: '2021-01-01' }
            use :pagination
          end

          desc "Get the ssh_keys for the user belonging to group" do
            detail 'This feature was introduced in GitLab 17.9.'
            success Entities::SshKeyWithUserId
          end

          get feature_category: :system_access do
            ssh_keys = ::KeysFinder.new(ssh_keys_finder_params).execute.preload_users

            present paginate(ssh_keys), with: Entities::SshKeyWithUserId
          end
        end
      end
    end
  end
end
