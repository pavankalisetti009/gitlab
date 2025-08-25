# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class UpdateService < Ai::Catalog::BaseService
        include FlowHelper

        def initialize(project:, current_user:, params:)
          @flow = params[:flow]
          super
        end

        def execute
          return error_max_steps if max_steps_exceeded?
          return error_no_permissions(payload: payload) unless allowed?
          return error('Flow not found') unless valid_flow?
          return error(steps_validation_errors) unless steps_valid?

          item_params = params.slice(:name, :description, :public)
          flow.assign_attributes(item_params)

          prepare_version_to_update

          if flow.save
            track_ai_item_events('update_ai_catalog_item', flow.item_type)
            return ServiceResponse.success(payload: payload)
          end

          error(flow.errors.full_messages)
        end

        private

        attr_reader :flow

        def valid_flow?
          flow && flow.flow?
        end

        def payload
          { flow: flow }
        end

        def error(message)
          super(message, payload: payload)
        end

        def prepare_version_to_update
          version_to_update = determine_version_to_update

          # A change to a version's definition will always cause its definition to match
          # the latest schema version, so ensure that it is set to the latest.
          if version_to_update.definition_changed?
            version_to_update.schema_version = Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION
          end

          version_to_update.release_date ||= Time.zone.now if params[:release] == true
          version_to_update
        end

        def determine_version_to_update
          latest_version = flow.latest_version
          version_params = build_version_params(latest_version)
          latest_version.assign_attributes(version_params)

          return latest_version unless latest_version.changed?
          return latest_version unless should_create_new_version?(latest_version)

          build_new_version(latest_version, version_params)
        end

        def build_version_params(latest_version)
          return {} unless params.key?(:steps)

          {
            definition: latest_version.definition.merge(steps: steps)
          }
        end

        def should_create_new_version?(version)
          version.released? && version.enforce_readonly_versions?
        end

        def build_new_version(latest_version, version_params)
          new_version_params = version_params.merge(
            version: calculate_next_version(latest_version)
          )

          flow.build_new_version(new_version_params)
        end

        def calculate_next_version(latest_version)
          # TODO: Support params[:version_bump] parameter.
          # For now, always make a major version bump.
          latest_version.version_bump(Ai::Catalog::ItemVersion::VERSION_BUMP_MAJOR)
        end
      end
    end
  end
end
