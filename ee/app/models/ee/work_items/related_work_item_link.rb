# frozen_string_literal: true

module EE
  module WorkItems
    module RelatedWorkItemLink
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      prepended do
        has_one :related_epic_link, class_name: '::Epic::RelatedEpicLink', foreign_key: 'issue_link_id',
          inverse_of: :related_work_item_link

        scope :for_source_type, ->(type) { joins(source: [:work_item_type]).where(source: { work_item_type_id: type }) }
        scope :for_target_type, ->(type) { joins(target: [:work_item_type]).where(target: { work_item_type_id: type }) }

        scope :preload_for_epic_link, -> { preload(:related_epic_link, source: [:synced_epic], target: [:synced_epic]) }
      end

      def synced_related_epic_link
        return unless source.synced_epic || target.synced_epic

        ::Epic::RelatedEpicLink.find_by(source: source.synced_epic, target: target.synced_epic)
      end
      strong_memoize_attr :synced_related_epic_link
    end
  end
end
