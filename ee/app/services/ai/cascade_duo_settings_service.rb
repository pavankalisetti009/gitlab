# frozen_string_literal: true

module Ai
  class CascadeDuoSettingsService
    DUO_SETTINGS = %w[duo_features_enabled duo_remote_flows_enabled auto_duo_code_review_enabled].freeze

    def initialize(setting_attributes)
      @setting_attributes = setting_attributes.stringify_keys

      check_setting_attributes!
    end

    def cascade_for_group(group)
      return if @setting_attributes.empty?

      update_subgroups(group)
      update_projects(group)
    end

    def cascade_for_instance
      return if @setting_attributes.empty?

      ProjectSetting.each_batch(of: 25000) do |batch|
        batch.update_all(@setting_attributes)
      end

      ::NamespaceSetting.each_batch(of: 25000) do |batch|
        batch.update_all(@setting_attributes)
      end
    end

    private

    def check_setting_attributes!
      return if @setting_attributes.keys.all? { |key| DUO_SETTINGS.include?(key) }

      raise ArgumentError,
        "Invalid key in #{@setting_attributes}. Only the following Duo Settings can cascade: #{DUO_SETTINGS}"
    end

    def update_subgroups(group)
      group.self_and_descendants.each_batch do |batch|
        namespace_ids = batch.pluck_primary_key
        ::NamespaceSetting.for_namespaces(namespace_ids)
                          .update_all(@setting_attributes)
      end
    end

    def update_projects(group)
      group.all_projects.each_batch do |batch|
        project_ids_to_update = batch.pluck_primary_key
        ProjectSetting.for_projects(project_ids_to_update)
                      .update_all(@setting_attributes)
      end
    end
  end
end
