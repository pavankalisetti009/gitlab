# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class CreateService < Ai::Catalog::BaseService
        include Gitlab::Utils::StrongMemoize

        SCHEMA_VERSION = 1
        MAX_STEPS = 100

        def execute
          return error_no_permissions unless allowed?
          return error("Maximum steps for a flow (#{MAX_STEPS}) exceeded") if params[:steps]&.count&.> MAX_STEPS

          item_params = params.slice(:name, :description, :public)
          item_params.merge!(
            item_type: Ai::Catalog::Item::FLOW_TYPE,
            organization_id: project.organization_id,
            project_id: project.id
          )
          version_params = {
            schema_version: SCHEMA_VERSION,
            version: DEFAULT_VERSION,
            definition: {
              triggers: [],
              steps: steps || []
            }
          }

          item = Ai::Catalog::Item.new(item_params)
          item.versions.build(version_params)

          if item.save
            track_ai_item_events('create_ai_catalog_item', item.item_type)
            return ServiceResponse.success(payload: { item: item })
          end

          error_creating(item)
        end

        private

        def steps
          params[:steps]&.map do |step|
            agent = step[:agent]

            pinned_version_prefix = step[:pinned_version_prefix]
            current_version_id = agent.resolve_version(pinned_version_prefix)&.id
            raise ArgumentError if !agent.agent? || current_version_id.nil?

            {
              agent_id: agent.id,
              current_version_id: current_version_id,
              pinned_version_prefix: pinned_version_prefix
            }
          end
        end
        strong_memoize_attr :steps

        def error_creating(item)
          error(item.errors.full_messages.presence || 'Failed to create flow')
        end

        def allowed?
          return false unless super

          params[:steps]&.each do |step|
            return false unless Ability.allowed?(current_user, :read_ai_catalog_item, step[:agent])
          end

          true
        end
      end
    end
  end
end
