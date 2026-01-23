# frozen_string_literal: true

module Search
  module Elastic
    class WorkItemGroupQueryBuilder < ::Search::Elastic::WorkItemQueryBuilder
      extend ::Gitlab::Utils::Override

      private

      override :get_confidentiality_filter
      def get_confidentiality_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_group_level_confidentiality(query_hash: query_hash, options: options)
      end

      override :get_authorization_filter
      def get_authorization_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_search_level_and_group_membership(query_hash: query_hash, options: options)
      end

      override :extra_options
      def extra_options
        # reference for epic visibility: https://docs.gitlab.com/user/group/epics/manage_epics/#who-can-view-an-epic
        super.merge({
          use_project_authorization: false,
          use_group_authorization: true,
          features: nil
        })
      end
    end
  end
end
