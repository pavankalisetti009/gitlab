# frozen_string_literal: true

module WorkItems
  class StatusFilter < ::Issuables::BaseFilter
    def filter(issuables)
      return issuables unless @parent&.root_ancestor.try(:work_item_status_feature_available?)
      return issuables unless issuables.respond_to?(:with_status)

      status = params.dig(:status, :id)
      status = find_status_by_name(params.dig(:status, :name)) unless status.present?

      return issuables unless status.present?

      issuables.with_status(status)
    end

    private

    def find_status_by_name(name)
      return unless name.present?

      ::WorkItems::Statuses::SystemDefined::Status.find_by_name(name)
    end
  end
end
