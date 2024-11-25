# frozen_string_literal: true

module API
  class GroupEnterpriseUsers < ::API::Base
    include PaginationParams

    feature_category :user_management

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

        users = finder.execute.preload(:identities, :scim_identities) # rubocop: disable CodeReuse/ActiveRecord -- preload

        present paginate(users), with: ::API::Entities::UserPublic
      end
    end
  end
end
