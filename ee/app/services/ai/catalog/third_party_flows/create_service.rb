# frozen_string_literal: true

module Ai
  module Catalog
    module ThirdPartyFlows
      class CreateService < Ai::Catalog::BaseService
        include Concerns::YamlDefinitionParser

        def execute
          return error_no_permissions unless allowed?

          item_params = params.slice(:name, :description, :public)
          item_params.merge!(
            item_type: Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE,
            organization_id: project.organization_id,
            project_id: project.id
          )

          definition = parsed_yaml_definition_or_error('ThirdPartyFlow')
          return definition if definition.is_a?(ServiceResponse)

          version_params = {
            schema_version: Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION,
            version: DEFAULT_VERSION,
            definition: definition,
            release_date: Time.zone.now
          }

          item = Ai::Catalog::Item.new(item_params)
          item.build_new_version(version_params)

          return error_creating(item) unless save_item(item)

          track_ai_item_events('create_ai_catalog_item', { label: item.item_type })
          send_audit_events('create_ai_catalog_third_party_flow', item)

          ServiceResponse.success(payload: { item: item })
        end

        private

        def allowed?
          super && Feature.enabled?(:ai_catalog_third_party_flows, current_user)
        end

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
          error(item.errors.full_messages.presence || 'Failed to create third party flow')
        end
      end
    end
  end
end
