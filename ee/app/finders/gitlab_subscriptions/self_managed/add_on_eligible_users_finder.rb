# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class AddOnEligibleUsersFinder
      attr_reader :add_on_type, :search_term

      def initialize(add_on_type:, search_term: nil)
        @add_on_type = add_on_type
        @search_term = search_term
      end

      def execute
        return ::User.none unless GitlabSubscriptions::AddOn::DUO_ADD_ONS.include?(add_on_type)

        users = ::User.active.without_bots.without_ghosts

        search_term ? users.search(search_term) : users.ordered_by_id_desc
      end
    end
  end
end
