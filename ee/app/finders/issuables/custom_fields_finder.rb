# frozen_string_literal: true

module Issuables
  class CustomFieldsFinder
    def initialize(current_user, group:, active: nil)
      raise ArgumentError, 'group argument is missing' if group.nil?

      @current_user = current_user
      @group = group
      @active = active
    end

    def execute
      return Issuables::CustomField.none unless Feature.enabled?('custom_fields_feature', @group)
      return Issuables::CustomField.none unless Ability.allowed?(@current_user, :read_custom_field, @group)

      items = Issuables::CustomField.of_namespace(@group)
      items = by_status(items)
      items.ordered_by_status_and_name
    end

    private

    def by_status(items)
      return items if @active.nil?

      if @active
        items.active
      else
        items.archived
      end
    end
  end
end
