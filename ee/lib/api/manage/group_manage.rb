# frozen_string_literal: true

module API
  module Manage
    class GroupManage < ::API::Base
      feature_category :system_access

      include PaginationParams

      before do
        not_found! unless Feature.enabled?(:manage_pat_by_group_owners_ready, user_group)

        authenticate_non_get!
        authorize! :admin_group, user_group
      end

      helpers do
        def users
          user_group.enterprise_users
        end

        def finder_params
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
            optional :revoked, type: Boolean, desc: 'Filter PATs where revoked state matches parameter',
              documentation: { example: false }
            optional :state, type: String, desc: 'Filter PATs which are either active or not',
              values: %w[active inactive], documentation: { example: 'active' }
            optional :created_before, type: DateTime, desc: 'Filter PATs which were created before given datetime',
              documentation: { example: '2022-01-01' }
            optional :created_after, type: DateTime, desc: 'Filter PATs which were created after given datetime',
              documentation: { example: '2021-01-01' }
            optional :last_used_before, type: DateTime, desc: 'Filter PATs which were used before given datetime',
              documentation: { example: '2021-01-01' }
            optional :last_used_after, type: DateTime, desc: 'Filter PATs which were used after given datetime',
              documentation: { example: '2022-01-01' }
            optional :search, type: String, desc: 'Filters PATs by its name', documentation: { example: 'token' }

            use :pagination
          end

          desc 'Get Personal access tokens' do
            detail 'This feature was introduced in GitLab 17.8.'
          end
          get do
            authorize! :admin_group, user_group

            tokens = PersonalAccessTokensFinder.new(finder_params).execute

            tokens.preload_users
            present paginate(tokens), with: Entities::PersonalAccessToken
          end
        end
      end
    end
  end
end
