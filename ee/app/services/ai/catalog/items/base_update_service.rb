# frozen_string_literal: true

module Ai
  module Catalog
    module Items
      class BaseUpdateService < Ai::Catalog::BaseService
        ITEM_ATTRIBUTES = %i[name description public].freeze

        def initialize(project:, current_user:, params:)
          @item = params[:item]
          super
        end

        def execute
          return error_no_permissions(payload: payload) unless allowed?

          item_validation = validate_item
          return item_validation if item_validation&.error?

          prepare_item_to_update
          prepare_version_to_update

          item.latest_released_version = item.latest_version if item.latest_version.released?

          save_item

          if item.saved_changes?
            track_ai_item_events('update_ai_catalog_item', { label: item.item_type })
            return ServiceResponse.success(payload: payload)
          end

          error(item.errors.full_messages)
        end

        private

        attr_reader :item

        def allowed?
          super && Ability.allowed?(current_user, :admin_ai_catalog_item, item)
        end

        def prepare_item_to_update
          item_params = params.slice(*ITEM_ATTRIBUTES)
          item.assign_attributes(item_params)
        end

        def prepare_version_to_update
          version_to_update = determine_version_to_update

          # A change to a version's definition will always cause its definition to match
          # the latest schema version, so ensure that it is set to the latest.
          version_to_update.schema_version = latest_schema_version if version_to_update.definition_changed?
          version_to_update.version = calculate_next_version if should_calculate_version?(version_to_update)
          version_to_update.release_date ||= Time.zone.now if params[:release] == true
          version_to_update
        end

        def determine_version_to_update
          latest_version = item.latest_version
          version_params = build_version_params(latest_version)
          latest_version.assign_attributes(version_params)

          return latest_version unless should_create_new_version?(latest_version)

          build_new_version(version_params)
        end

        def should_create_new_version?(version)
          version.definition_changed? && version.released? && version.enforce_readonly_versions?
        end

        def build_new_version(version_params)
          item.build_new_version(version_params)
        end

        def should_calculate_version?(version)
          version.new_record? || params[:version_bump].present?
        end

        def calculate_next_version
          # TODO replace with item.latest_released_version once
          # https://gitlab.com/gitlab-org/gitlab/-/issues/554673 is completed
          latest_released_version = item.versions.where.not(release_date: nil).order(id: :desc).take # rubocop:disable CodeReuse/ActiveRecord -- Will be fixed after https://gitlab.com/gitlab-org/gitlab/-/issues/554673

          return BaseService::DEFAULT_VERSION unless latest_released_version

          bump_level = params[:version_bump] || Ai::Catalog::ItemVersion::VERSION_BUMP_MAJOR
          latest_released_version.version_bump(bump_level)
        end

        def payload
          { item: item }
        end

        def error(message)
          super(message, payload: payload)
        end

        def validate_item
          raise NotImplementedError
        end

        def latest_schema_version
          raise NotImplementedError
        end

        def build_version_params(_latest_version)
          raise NotImplementedError
        end

        def save_item
          raise NotImplementedError
        end
      end
    end
  end
end
