# frozen_string_literal: true

module WorkItems
  module HasStatus
    extend ActiveSupport::Concern

    included do
      has_one :current_status, class_name: 'WorkItems::Statuses::CurrentStatus',
        foreign_key: 'work_item_id', inverse_of: :work_item

      scope :with_status, ->(status) {
        # TODO: add case when custom status is introduced
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/520311
        joins(:current_status).where(work_item_current_statuses: { system_defined_status_id: status.id })
      }
    end
  end
end
