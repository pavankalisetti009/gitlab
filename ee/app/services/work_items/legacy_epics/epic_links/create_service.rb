# frozen_string_literal: true

module WorkItems
  module LegacyEpics
    module EpicLinks
      class CreateService
        include ::Gitlab::Utils::StrongMemoize

        ALREADY_ASSIGNED_ERROR_MSG = "already assigned"
        NOT_FOUND_ERROR_MSG = "No matching work item found"

        def initialize(legacy_epic, user, params)
          @legacy_epic = legacy_epic
          @user = user
          @params = params
          @previous_parent_links = []
        end

        def execute
          @previous_parent_links = target_work_items.each_with_object({}) do |work_item, hash|
            hash[work_item.id] = work_item.parent_link.work_item_parent_id if work_item.parent_link&.work_item_parent_id
          end

          ::WorkItems::UpdateService.new(
            container: parent_work_item.resource_parent,
            current_user: user,
            params: {},
            widget_params: { hierarchy_widget: { children: target_work_items } }
          ).execute(parent_work_item).then do |result|
            transform_result(result)
          end
        end

        private

        def parent_work_item
          legacy_epic.work_item
        end
        strong_memoize_attr :parent_work_item

        def target_work_items
          target_issuable = params[:target_issuable]

          if params[:issuable_references].present?
            WorkItem.id_in(referenced_epics.filter_map(&:issue_id))
          elsif target_issuable
            WorkItem.id_in(Array.wrap(target_issuable).map(&:issue_id))
          else
            []
          end
        end
        strong_memoize_attr :target_work_items

        def referenced_epics
          extractor = Gitlab::ReferenceExtractor.new(nil, user)
          extractor.analyze(params[:issuable_references]&.join(' '), { group: legacy_epic.group })
          extractor.epics
        end

        def transform_result(result)
          if result[:status] == :success
            result.delete(:message)
            result.delete(:work_item)

            result[:created_references] = target_work_items.filter_map do |work_item|
              next if previous_parent_links[work_item.id] == work_item.reset.parent_link&.work_item_parent_id
              next if work_item.parent_link.nil?

              work_item.synced_epic
            end
          else
            transform_error(result)
          end

          result
        end

        def transform_error(result)
          result[:http_status] = 422 if result[:http_status] == :unprocessable_entity
          error_message = ::Gitlab::WorkItems::IssuableLinks::ErrorMessage.new(target_type: 'epic',
            container_type: 'group')

          if result[:message].include?(ALREADY_ASSIGNED_ERROR_MSG)
            result[:http_status] = 409
            result[:message] = error_message.already_assigned
          elsif result[:message].include?(NOT_FOUND_ERROR_MSG)
            result[:http_status] = 404
            result[:message] = error_message.not_found
          else
            result[:message] = result[:message].gsub("work item", "epic")
          end
        end

        attr_reader :legacy_epic, :user, :params, :previous_parent_links
      end
    end
  end
end
