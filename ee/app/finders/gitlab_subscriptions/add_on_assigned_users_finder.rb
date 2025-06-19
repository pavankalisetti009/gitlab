# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnAssignedUsersFinder
    include Gitlab::Utils::StrongMemoize
    include Concerns::HistoricalAddOnAssignedUsers

    def initialize(current_user, namespace, add_on_name:, after: nil, before: nil)
      @current_user = current_user
      @namespace = namespace
      @add_on_name = add_on_name
      @after = after
      @before = before
    end

    def execute
      if after || before
        historical_add_on_assigned_users
      else
        current_add_on_assigned_users
      end
    end

    private

    attr_reader :namespace, :current_user, :add_on_name, :after, :before

    def current_add_on_assigned_users
      add_on_purchase = GitlabSubscriptions::AddOnPurchase
        .by_add_on_name(add_on_name)
        .by_namespace([namespace.root_ancestor, nil])
        .active
        .first

      return User.none unless add_on_purchase

      add_on_purchase.users.by_ids(namespace_members.reselect(:user_id))
    end

    def namespace_members
      # rubocop:disable CodeReuse/Finder -- member finders logic is way too complex to reconstruct it with scopes.
      if namespace.is_a?(Namespaces::ProjectNamespace)
        MembersFinder.new(namespace.project, current_user).execute(include_relations: %i[direct inherited descendants])
      else
        GroupMembersFinder.new(namespace, current_user).execute(include_relations: %i[direct inherited descendants])
      end
      # rubocop:enable CodeReuse/Finder
    end
  end
end
