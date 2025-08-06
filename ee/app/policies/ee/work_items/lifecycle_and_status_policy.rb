# frozen_string_literal: true

module EE
  module WorkItems
    module LifecycleAndStatusPolicy
      extend ActiveSupport::Concern

      included do
        condition(:maintain_root_group) do
          can?(:maintainer_access, @subject.root_ancestor)
        end

        condition(:work_item_statuses_available, scope: :subject) do
          @subject.licensed_feature_available?(:work_item_status)
        end

        rule { can?(:read_work_item) & work_item_statuses_available }.policy do
          enable :read_work_item_lifecycle
          enable :read_work_item_status
        end

        rule { maintain_root_group & work_item_statuses_available }.policy do
          enable :admin_work_item_lifecycle
        end
      end
    end
  end
end
