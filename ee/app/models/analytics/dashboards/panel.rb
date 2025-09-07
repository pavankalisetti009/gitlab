# frozen_string_literal: true

module Analytics
  module Dashboards
    class Panel
      attr_reader :title, :tooltip, :grid_attributes, :visualization, :config_project, :query_overrides, :container

      def self.from_data(panel_yaml, config_project, container)
        return if panel_yaml.nil?

        panel_yaml.map do |panel|
          new(
            title: panel['title'],
            tooltip: panel['tooltip'],
            config_project: config_project,
            container: container,
            grid_attributes: panel['gridAttributes'],
            query_overrides: panel['queryOverrides'],
            visualization_config: panel['visualization']
          )
        end
      end

      def initialize(
        title:, container:, grid_attributes:, visualization_config:, config_project:,
        query_overrides:, tooltip:)
        @title = title
        @tooltip = tooltip
        @config_project = config_project
        @container = container
        @grid_attributes = grid_attributes
        @query_overrides = query_overrides

        return if visualization_config.blank?

        @visualization = if visualization_config.is_a?(String)
                           Visualization.from_file(
                             filename: visualization_config,
                             config_project: config_project,
                             container: container
                           )
                         else
                           Visualization.from_data(data: visualization_config,
                             container: container)
                         end
      end
    end
  end
end
