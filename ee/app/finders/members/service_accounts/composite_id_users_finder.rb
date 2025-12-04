# frozen_string_literal: true

module Members
  module ServiceAccounts
    # Filters a User relation to keep only allowed users based on composite id service account rules.
    # Refer to the base class for more details.
    #
    # @example Filter a User relation
    #   Members::ServiceAccounts::CompositeIdUsersFinder.new(group).execute(users_relation)
    class CompositeIdUsersFinder < CompositeIdFinder
      # rubocop: disable CodeReuse/ActiveRecord -- required by the nature of finder
      # Filters a User relation
      def execute(users_relation)
        users_relation
          .joins(:user_detail)
          .where(*allowed_conditions)
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
