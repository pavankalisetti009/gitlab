# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class CreateService < Ai::Catalog::BaseService
        def execute
          return error_no_permissions unless allowed?

          item_params = params.slice(:name, :description, :public)
          item_params.merge!(
            item_type: Ai::Catalog::Item::AGENT_TYPE,
            organization_id: project.organization_id,
            project_id: project.id
          )

          version_params = {
            schema_version: Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION,
            version: DEFAULT_VERSION,
            definition: {
              tools: Array(params[:tools]).map(&:id),
              system_prompt: params[:system_prompt],
              user_prompt: params[:user_prompt] || ""
            }
          }
          version_params[:release_date] = Time.zone.now if params[:release] == true

          item = Ai::Catalog::Item.new(item_params)
          item.build_new_version(version_params)

          return error_creating(item) unless save_item(item)

          track_ai_item_events('create_ai_catalog_item', { label: item.item_type })

          if params[:add_to_project_when_created]
            service_response = ::Ai::Catalog::ItemConsumers::CreateService.new(
              container: project,
              current_user: current_user,
              params: { item: item }
            ).execute

            return error(service_response.errors, payload: { item: item }) if service_response.error?
          end

          ServiceResponse.success(payload: { item: item })
        end

        private

        def save_item(item)
          Ai::Catalog::Item.transaction do
            item.save!
            item.update!(latest_released_version: item.latest_version) if item.latest_version.released?
            true
          end
        rescue ActiveRecord::RecordInvalid
          false
        end

        def error_creating(item)
          error(item.errors.full_messages.presence || 'Failed to create agent')
        end
      end
    end
  end
end
