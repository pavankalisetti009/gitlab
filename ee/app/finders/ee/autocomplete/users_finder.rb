# frozen_string_literal: true

module EE
  module Autocomplete # rubocop:disable Gitlab/BoundedContexts -- FOSS finder is not bounded to a context
    module UsersFinder
      extend ::Gitlab::Utils::Override

      override :initialize
      def initialize(params:, current_user:, project:, group:)
        super
        @hide_service_accounts_without_flow_triggers = params[:hide_service_accounts_without_flow_triggers]
      end

      private

      override :project_users
      def project_users
        users = super

        # rubocop:disable CodeReuse/ActiveRecord -- Finders should be excluded from this cop
        if hide_service_accounts_without_flow_triggers
          users = users.where(users.arel_table[:id].not_in(unused_service_accounts))
        end
        # rubocop:enable CodeReuse/ActiveRecord

        if project.ai_review_merge_request_allowed?(current_user)
          users = users.union_with_user(::Users::Internal.duo_code_review_bot)
        end

        users
      end

      def unused_service_accounts
        parent = ::Ai::Catalog::ItemConsumer.arel_table
        children = ::Ai::Catalog::ItemConsumer.arel_table.alias('children')
        triggers = ::Ai::FlowTrigger.arel_table.alias('triggers')

        # rubocop:disable CodeReuse/ActiveRecord -- Finders should be excluded from this cop
        parent
          .project(parent[:service_account_id])
          .join(children)
          .on(children[:parent_item_consumer_id].eq(parent[:id]))
          .join(triggers, Arel::Nodes::OuterJoin)
          .on(triggers[:ai_catalog_item_consumer_id].eq(children[:id]))
          .where(parent[:group_id].eq(project.root_ancestor.id))
          .group(parent[:id])
          .having(Arel::Nodes::SqlLiteral.new('COUNT(triggers.id) = 0'))
        # rubocop:enable CodeReuse/ActiveRecord
      end
    end
  end
end
