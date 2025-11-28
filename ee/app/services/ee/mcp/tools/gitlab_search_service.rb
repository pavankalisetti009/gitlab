# frozen_string_literal: true

module EE
  module Mcp
    module Tools
      module GitlabSearchService
        extend ::Gitlab::Utils::Override

        override :transform_arguments
        def transform_arguments(args)
          transformed = super
          apply_context_exclusion(transformed)
        end

        private

        def apply_context_exclusion(args)
          # Only apply exclusion for blobs and wiki_blobs scopes
          return args unless %w[blobs wiki_blobs].include?(args[:scope])

          project = find_project(args)
          return args unless project

          exclusion_rules = load_exclusion_rules(project)
          return args if exclusion_rules.empty?

          # Append -filename: or -path: filters to search query
          # Use -path: for patterns with '/', -filename: for simple filenames
          exclusion_filters = exclusion_rules.map do |pattern|
            filter_type = pattern.include?('/') ? 'path' : 'filename'
            "-#{filter_type}:#{pattern}"
          end.join(' ')
          args[:search] = "#{args[:search]} #{exclusion_filters}".strip

          args
        end

        def find_project(args)
          return unless args[:id]

          ::Project.find_by_id(args[:id]) || ::Project.find_by_full_path(args[:id])
        end

        def load_exclusion_rules(project)
          settings = project.project_setting&.duo_context_exclusion_settings

          Hash(settings).fetch('exclusion_rules', [])
        end

        def advanced_search_enabled?
          ::Gitlab::CurrentSettings.elasticsearch_search?
        end

        def exact_code_search_enabled?
          ::Search::Zoekt.enabled?
        end
      end
    end
  end
end
