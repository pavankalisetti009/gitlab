# frozen_string_literal: true

module API
  module Entities
    class Epic < Grape::Entity
      include ::API::Helpers::RelatedResourcesHelpers
      include ::API::Helpers::Presentable

      expose :id, documentation: { type: 'Integer', example: 123 }
      expose :work_item_id, documentation: {
        type: 'Integer', example: 123, documentation: "ID of the corresponding work item for a legacy epic"
      }
      expose :iid, documentation: { type: 'Integer', example: 123 } do |epic|
        epic.work_item.iid
      end

      expose :color, documentation: { type: 'String', example: "#1068bf" } do |epic|
        epic.work_item.color&.color.to_s
      end

      expose :text_color, documentation: { type: 'String', example: "#1068bf" } do |epic|
        epic.work_item.color&.text_color.to_s
      end

      expose :group_id, documentation: { type: 'Integer', example: 17 } do |epic|
        epic.work_item.namespace_id
      end

      expose :parent_id, documentation: { type: 'Integer', example: 12 } do |epic|
        next nil unless epic.work_item_parent_link_id

        epic.work_item.parent_link&.work_item_parent&.sync_object&.id
      end

      expose :parent_iid, documentation: { type: 'Integer', example: 19 } do |epic|
        next nil unless epic.work_item_parent_link_id

        epic.work_item.parent_link&.work_item_parent&.iid
      end

      expose :imported?, as: :imported, documentation: { type: 'Boolean', example: false } do |epic|
        epic.work_item.imported?
      end

      expose :imported_from, documentation: { type: 'String', example: "github" } do |epic|
        epic.work_item.imported_from
      end

      expose :title, documentation: { type: 'String', example: "My Epic" } do |epic|
        epic.work_item.title
      end

      expose :description, documentation: { type: 'String', example: "Epic description" } do |epic|
        epic.work_item.description
      end

      expose :confidential, documentation: { type: 'Boolean', example: false } do |epic|
        epic.work_item.confidential
      end

      expose :author, using: ::API::Entities::UserBasic do |epic|
        epic.work_item.author
      end

      expose :start_date, documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.start_date
      end

      expose :start_date_is_fixed?,
        as: :start_date_is_fixed,
        documentation: { type: 'Boolean', example: true } do |_epic|
        rollupable_dates.fixed?
      end

      expose :start_date_fixed,
        documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.start_date
      end

      expose :start_date_from_inherited_source,
        documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.start_date&.to_time&.iso8601
      end

      expose :start_date_from_milestones, # @deprecated in favor of start_date_from_inherited_source
        documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.start_date&.to_time&.iso8601
      end

      expose :end_date, # @deprecated in favor of due_date
        documentation: { type: "DateTime", example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.due_date
      end

      expose :end_date,
        as: :due_date,
        documentation: { type: "DateTime", example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.due_date
      end

      expose :due_date_is_fixed?,
        as: :due_date_is_fixed,
        documentation: { type: 'Boolean', example: true } do |_epic|
        rollupable_dates.fixed?
      end

      expose :due_date_fixed,
        documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.due_date
      end

      expose :due_date_from_inherited_source,
        documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.due_date&.to_time&.iso8601
      end

      expose :due_date_from_milestones, # @deprecated in favor of due_date_from_inherited_source
        documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |_epic|
        rollupable_dates.due_date&.to_time&.iso8601
      end

      expose :state, documentation: { type: 'String', example: "opened" } do |epic|
        epic.work_item.state
      end
      expose :web_edit_url, # @deprecated
        documentation: { type: 'String', example: "http://gitlab.example.com/groups/test/-/epics/4/edit" }
      expose :web_url, documentation: { type: 'String', example: "http://gitlab.example.com/groups/test/-/epics/4" }
      expose :references, documentation: { is_array: true } do |epic, options|
        ::API::Entities::IssuableReferences.represent(epic, group: options[:user_group])
      end
      # reference is deprecated in favour of references
      # Introduced [Gitlab 12.6](https://gitlab.com/gitlab-org/gitlab/merge_requests/20354)
      expose :reference, if: { with_reference: true } do |epic|
        epic.to_reference(full: true)
      end
      expose :created_at, documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |epic|
        epic.work_item.created_at
      end

      expose :updated_at, documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |epic|
        epic.work_item.updated_at
      end

      expose :closed_at, documentation: { type: 'DateTime', example: "2022-01-31T15:10:45.080Z" } do |epic|
        epic.work_item.closed_at
      end
      expose :labels, documentation: { is_array: true } do |epic, options|
        labels = epic.labels.sort_by(&:title)

        options[:with_labels_details] ? ::API::Entities::LabelBasic.represent(labels) : labels.map(&:title)
      end
      expose :upvotes, documentation: { type: 'Integer', example: 4 } do |epic, options|
        if options[:issuable_metadata]
          # Avoids an N+1 query when metadata is included
          options[:issuable_metadata][epic.id].upvotes
        else
          epic.upvotes
        end
      end
      expose :downvotes, documentation: { type: 'Integer', example: 3 } do |epic, options|
        if options[:issuable_metadata]
          # Avoids an N+1 query when metadata is included
          options[:issuable_metadata][epic.id].downvotes
        else
          epic.downvotes
        end
      end

      # Calculating the value of subscribed field triggers Markdown
      # processing. We can't do that for multiple epics
      # requests in a single API request.
      expose :subscribed?,
        as: :subscribed,
        documentation: { type: 'Boolean', example: true },
        if: ->(_, options) { options.fetch(:include_subscribed, false) }

      def web_url
        ::Gitlab::Routing.url_helpers.group_epic_url(object.group, object)
      end

      def web_edit_url
        ::Gitlab::Routing.url_helpers.group_epic_path(object.group, object)
      end

      def rollupable_dates
        object.work_item.get_widget(:start_and_due_date)
      end

      expose :_links do
        expose :self,
          documentation: {
            type: 'String',
            example: "http://gitlab.example.com/api/v4/groups/7/epics/5"
          } do |epic|
            expose_url(api_v4_groups_epics_path(id: epic.group_id, epic_iid: epic.iid))
          end

        expose :epic_issues,
          documentation: {
            type: 'String',
            example: "http://gitlab.example.com/api/v4/groups/7/epics/5/issues"
          } do |epic|
            expose_url(api_v4_groups_epics_issues_path(id: epic.group_id, epic_iid: epic.iid))
          end

        expose :group,
          documentation: {
            type: 'String',
            example: "http://gitlab.example.com/api/v4/groups/7"
          } do |epic|
            expose_url(api_v4_groups_path(id: epic.group_id))
          end

        expose :parent,
          documentation: {
            type: 'String',
            example: "http://gitlab.example.com/api/v4/groups/7/epics/4"
          } do |epic|
            if epic.has_parent?
              expose_url(api_v4_groups_epics_path(id: epic.parent.group_id, epic_iid: epic.parent.iid))
            end
          end
      end
    end
  end
end
