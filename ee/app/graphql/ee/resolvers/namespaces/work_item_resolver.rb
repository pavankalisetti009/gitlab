# ee/app/graphql/ee/resolvers/namespaces/work_item_resolver.rb
# frozen_string_literal: true

module EE
  module Resolvers
    module Namespaces
      module WorkItemResolver
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class_methods do
          extend ::Gitlab::Utils::Override

          override :recent_services_map
          def recent_services_map
            super.merge(
              'epic' => ::Gitlab::Search::RecentEpics
            )
          end
        end
      end
    end
  end
end
