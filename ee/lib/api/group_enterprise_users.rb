# frozen_string_literal: true

module API
  class GroupEnterpriseUsers < ::API::Base
    include PaginationParams

    feature_category :user_management

    helpers Gitlab::InternalEventsTracking

    helpers do
      def track_get_group_enterprise_users_api
        track_internal_event(
          'use_get_group_enterprise_users_api',
          user: current_user,
          namespace: user_group
        )
      end
    end

    before do
      authenticate!
      bad_request!('Must be a top-level group') unless user_group.root?
      authorize! :owner_access, user_group
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
    end

    resource :groups, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a list of enterprise users of the group' do
        success ::API::Entities::UserPublic
        is_array true
      end
      params do
        optional :username, type: String, desc: 'Return single user with a specific username.'
        optional :search, type: String, desc: 'Search users by name, email, username.'
        optional :active, type: Grape::API::Boolean, default: false, desc: 'Return only active users.'
        optional :blocked, type: Grape::API::Boolean, default: false, desc: 'Return only blocked users.'
        optional :created_after, type: DateTime, desc: 'Return users created after the specified time.'
        optional :created_before, type: DateTime, desc: 'Return users created before the specified time.'
        optional(
          :two_factor,
          type: String,
          desc: 'Filter users by two-factor authentication (2FA). ' \
            'Filter values are `enabled` or `disabled`. By default it returns all users.'
        )

        use :pagination
      end
      get ':id/enterprise_users' do
        finder = ::Authn::EnterpriseUsersFinder.new(
          current_user,
          declared_params.merge(enterprise_group: user_group))

        users = finder.execute.preload(:identities, :group_scim_identities, :instance_scim_identities) # rubocop: disable CodeReuse/ActiveRecord -- preload

        track_get_group_enterprise_users_api

        present paginate(users), with: ::API::Entities::UserPublic
      end

      desc 'Get a single enterprise user of the group' do
        success ::API::Entities::UserPublic
      end
      params do
        requires :user_id, type: Integer, desc: 'ID of user account.'
      end
      get ":id/enterprise_users/:user_id" do
        user = user_group.enterprise_users.find(declared_params[:user_id])

        present user, with: ::API::Entities::UserPublic
      end

      desc 'Disable two factor authentication for an enterprise user'
      params do
        requires :user_id, type: Integer, desc: 'ID of user account.'
      end
      patch ":id/enterprise_users/:user_id/disable_two_factor" do
        user = user_group.enterprise_users.find(declared_params[:user_id])

        result = TwoFactor::DestroyService.new(current_user, user: user, group: user_group).execute

        if result[:status] == :success
          no_content!
        else
          bad_request!(result[:message])
        end
      end

      desc 'Modify an enterprise user' do
        success ::API::Entities::UserPublic
      end
      params do
        requires :user_id, type: Integer, desc: 'ID of user account.'
        optional :name, type: String, desc: 'Name of the user account.'
        optional :email, type: String, desc: 'Email address of the user account. Must be from a verified group domain.'
      end
      patch ":id/enterprise_users/:user_id" do
        user = user_group.enterprise_users.find(declared_params[:user_id])

        result = ::Users::UpdateService.new(
          current_user,
          declared_params(include_missing: false).except(:user_id).merge(user: user, force_name_change: true)
        ).execute do |user|
          user.skip_reconfirmation! if user.enterprise_group.owner_of_email?(declared_params[:email])
        end

        if result[:status] == :success
          present user, with: ::API::Entities::UserPublic
        else
          render_api_error!(result[:message], result[:reason] || :bad_request)
        end
      end

      desc 'Delete an enterprise user'
      params do
        requires :user_id, type: Integer, desc: 'ID of user account.'
        optional :hard_delete,
          type: Grape::API::Boolean,
          default: false,
          desc: 'If `false`, deletes the user and moves their contributions to a system-wide "Ghost User". If ' \
            '`true`, deletes the user, their associated contributions, and any groups owned solely by the user. ' \
            'Default value: `false`.'
      end
      delete ":id/enterprise_users/:user_id" do
        user = user_group.enterprise_users.find(declared_params[:user_id])

        authorize! :destroy_user, user

        unless user.can_be_removed? || declared_params[:hard_delete]
          conflict!('Can not remove a user who is the sole owner of a group.')
        end

        destroy_conditionally!(user) do
          user.delete_async(deleted_by: current_user, params: { hard_delete: declared_params[:hard_delete] })
        end
      end
    end
  end
end
