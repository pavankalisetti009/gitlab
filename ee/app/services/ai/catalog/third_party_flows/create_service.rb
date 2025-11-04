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
            definition: definition
          }
          version_params[:release_date] = Time.zone.now if params[:release] == true

          item = Ai::Catalog::Item.new(item_params)
          item.build_new_version(version_params)

          if item.save
            track_ai_item_events('create_ai_catalog_item', { label: item.item_type })
            return ServiceResponse.success(payload: { item: item })
          end

          error_creating(item)
        end

        private

        def allowed?
          super && Feature.enabled?(:ai_catalog_third_party_flows, current_user)
        end

        def error_creating(item)
          error(item.errors.full_messages.presence || 'Failed to create third party flow')
        end
      end
    end
  end
end
