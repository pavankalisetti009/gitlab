# frozen_string_literal: true

module API
  module Manage
    class Groups < ::API::Base
      feature_category :system_access

      include PaginationParams

      before do
        not_found! unless Feature.enabled?(:manage_pat_by_group_owners_ready, user_group)
        not_found! unless ::Gitlab::Saas.feature_available?(:group_credentials_inventory)

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
            include_missing: false).merge({ users: users, impersonation: false, owner_type: 'human' })
        end

        def bot_users
          User.by_bot_namespace_ids(user_group.self_and_descendants(skope: Namespace).as_ids)
        end

        def rat_finder_params
          declared(params, include_missing: false)
            .merge({ users: bot_users, impersonation: false })
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

          desc 'Revoke a personal access token for the group' do
            detail 'Revoke a personal access token by using the ID of the personal access token.'
            success code: 204
            failure [
              { code: 400, message: 'Bad Request' }
            ]
          end

          delete ':pat_id' do
            token = find_token(params[:pat_id])

            forbidden! unless users.include? token.user

            revoke_token(token, group: user_group)
          end
        end

        resources :resource_access_tokens do
          params do
            use :access_token_params
            use :pagination
          end

          desc 'Get resource access tokens' do
            detail 'This feature was introduced in GitLab 17.10.'
          end
          # rubocop:disable CodeReuse/ActiveRecord -- Specific to this endpoint
          get do
            tokens = PersonalAccessTokensFinder.new(rat_finder_params)
                                               .execute
                                               .includes(user: [:members, { user_detail: :bot_namespace }])

            present paginate(tokens), with: Entities::ResourceAccessToken
          end
          # rubocop:enable CodeReuse/ActiveRecord

          desc 'Revoke a resource access token for the group' do
            detail 'Revoke a resource access token by using the ID of the resource access token.'
            success code: 204
            failure [
              { code: 400, message: 'Bad Request' }
            ]
          end
          delete ':prat_id' do
            token = find_token(params[:prat_id])

            unless token.user.project_bot?
              forbidden!("Cannot revoke resource access token: token belongs to a human user, not a bot")
            end

            service = ::ResourceAccessTokens::RevokeService
              .new(current_user, user_group, token).execute

            service.success? ? no_content! : bad_request!(service.message)
          end
        end

        resources :ssh_keys do
          params do
            optional :created_before, type: DateTime, desc: 'Filter ssh keys which were created before given datetime',
              documentation: { example: '2022-01-01' }
            optional :created_after, type: DateTime, desc: 'Filter ssh keys which were created after given datetime',
              documentation: { example: '2021-01-01' }
            optional :expires_before, type: DateTime, desc: 'Filter ssh keys which expire before given datetime',
              documentation: { example: '2022-01-01' }
            optional :expires_after, type: DateTime, desc: 'Filter ssh keys which expire after given datetime',
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

          desc 'Delete an existing SSH key' do
            detail 'Delete an existing SSH key by using the ID of the key.'
            success code: 204
            failure [
              { code: 400, message: 'Bad Request' }
            ]
          end
          delete ':key_id' do
            key = ::KeysFinder.new(ssh_keys_finder_params).find_by_id(params[:key_id])

            not_found!('Key') unless key

            destroy_conditionally!(key) do |key|
              destroy_service = ::Keys::DestroyService.new(current_user)
              destroy_service.execute(key)
            end
          end
        end
      end
    end
  end
end
