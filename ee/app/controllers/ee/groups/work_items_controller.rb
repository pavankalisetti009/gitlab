# frozen_string_literal: true

module EE
  module Groups
    module WorkItemsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      prepended do
        before_action :authorize_read_work_item!, only: [:description_diff, :delete_description_version]

        before_action do
          push_force_frontend_feature_flag(
            :work_items_rolledup_dates,
            group&.work_items_rolledup_dates_feature_flag_enabled?
          )
        end

        include DescriptionDiffActions
      end

      private

      override :namespace_work_items_enabled?
      def namespace_work_items_enabled?
        super && ::Feature.enabled?(:work_item_epics_rollout, current_user)
      end

      def issuable
        ::WorkItem.find_by_namespace_and_iid!(group, params[:iid])
      end
      strong_memoize_attr :issuable

      def authorize_read_work_item!
        access_denied! unless can?(current_user, :read_work_item, issuable)
      end
    end
  end
end
