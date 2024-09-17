# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class AddOnEligibleUsersFinder
      attr_reader :add_on_type, :search_term, :sort

      def initialize(add_on_type:, search_term: nil, sort: nil)
        @add_on_type = add_on_type
        @search_term = search_term
        @sort = sort
      end

      def execute
        return ::User.none unless GitlabSubscriptions::AddOn::DUO_ADD_ONS.include?(add_on_type)

        users = ::User.active.without_bots.without_ghosts

        search_term ? users.search(search_term) : users.sort_by_attribute(sort)
      end
    end
  end
end
