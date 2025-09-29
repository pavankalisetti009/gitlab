# frozen_string_literal: true

module WorkItems
  class StatusFilter < ::Issuables::BaseFilter
    def filter(issuables)
      return issuables unless can_filter_by_status?(issuables)

      statuses_for_filtering = find_statuses_for_filtering
      return issuables.none unless statuses_for_filtering.present?

      apply_status_filters(issuables, statuses_for_filtering)
    end

    private

    def can_filter_by_status?(issuables)
      status_param_present? &&
        root_ancestor&.licensed_feature_available?(:work_item_status) &&
        issuables.respond_to?(:with_status)
    end

    def status_param_present?
      params[:status].to_h&.slice(:id, :name).present?
    end

    def find_statuses_for_filtering
      requested_status = find_requested_status
      return [] unless requested_status

      statuses = [{ status: requested_status, mapping: nil }]

      # Add any statuses that map to the requested status
      if requested_status.is_a?(::WorkItems::Statuses::Custom::Status)
        statuses.concat(find_statuses_mapping_to(requested_status))
      end

      statuses.uniq
    end

    def find_requested_status
      status = params.dig(:status, :id)
      status = find_status_by_name(params.dig(:status, :name)) unless status.present?
      status
    end

    def find_status_by_name(name)
      return unless name.present?

      ::WorkItems::Statuses::Finder.new(root_ancestor, { 'name' => name }).execute
    end

    def find_statuses_mapping_to(status)
      mappings_to_status = load_cached_mappings(root_ancestor).select { |m| m.new_status_id == status.id }
      return [] if mappings_to_status.empty?

      mappings_to_status.map do |mapping|
        {
          status: mapping.old_status,
          mapping: mapping
        }
      end
    end

    def load_cached_mappings(namespace)
      cache_key = "work_items:status_mappings_for_filter:#{namespace.id}"

      ::Gitlab::SafeRequestStore.fetch(cache_key) do
        ::WorkItems::Statuses::Custom::Mapping
          .with_namespace_id(namespace.id)
          .includes(:old_status) # rubocop:disable CodeReuse/ActiveRecord -- Preloading depends on the context
          .to_a
      end
    end

    def apply_status_filters(issuables, statuses_for_filtering)
      statuses_for_filtering.reduce(issuables.none) do |relation, status_mapping|
        relation.or(issuables.with_status(status_mapping[:status], status_mapping[:mapping]))
      end
    end

    def root_ancestor
      @parent&.root_ancestor
    end
  end
end
