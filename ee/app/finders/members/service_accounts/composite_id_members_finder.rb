# frozen_string_literal: true

module Members
  module ServiceAccounts
    # Filters a Member relation to keep only members with allowed users based on composite id service account rules.
    # Refer to the base class for more details.
    #
    # @example Filter a Member relation
    #   Members::ServiceAccounts::CompositeIdMembersFinder.new(group).execute(members_relation)
    class CompositeIdMembersFinder < CompositeIdFinder
      # rubocop: disable CodeReuse/ActiveRecord -- required by the nature of finder
      # Filters a Member relation by user
      def execute(members_relation)
        members_relation
          .joins(user: :user_detail)
          .where(*allowed_conditions)
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
