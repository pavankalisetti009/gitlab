# frozen_string_literal: true

module Resolvers
  module GitlabSubscriptions
    module SelfManaged
      class AddOnEligibleUsersResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource
        include ::GitlabSubscriptions::CodeSuggestionsHelper

        type [::Types::GitlabSubscriptions::AddOnUserType.connection_type], null: true

        argument :search,
          type: GraphQL::Types::String,
          required: false,
          description: 'Search the user list.'

        argument :add_on_type,
          type: Types::GitlabSubscriptions::AddOnTypeEnum,
          required: true,
          description: 'Type of add on to filter the eligible users by.'

        def resolve(add_on_type:, search: nil)
          authorize!

          users = ::GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(
            add_on_type: add_on_type,
            search_term: search
          ).execute

          offset_pagination(users)
        end

        private

        def authorize!
          return unless gitlab_com_subscription? || !current_user.can_admin_all_resources?

          raise_resource_not_available_error!
        end
      end
    end
  end
end
