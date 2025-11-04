# frozen_string_literal: true

module Ai
  module Catalog
    module Concerns
      module YamlDefinitionParser
        extend ActiveSupport::Concern
        include Gitlab::Utils::StrongMemoize

        private

        def definition_parsed
          return unless params[:definition].present?

          YAML.safe_load(params[:definition]).merge(yaml_definition: params[:definition])
        rescue Psych::SyntaxError
          nil
        end
        strong_memoize_attr :definition_parsed

        def valid_yaml_definition?
          return true unless params.key?(:definition)

          definition_parsed.present?
        end

        def yaml_syntax_error(item_type = 'Flow')
          error("#{item_type} definition does not have a valid YAML syntax")
        end

        def parsed_yaml_definition_or_error(item_type = 'Flow')
          return yaml_syntax_error(item_type) unless valid_yaml_definition?

          definition_parsed
        end

        def parsed_definition_param
          return {} unless should_update_definition?

          { definition: definition_parsed }
        end

        def should_update_definition?
          params.key?(:definition) && definition_parsed.present?
        end
      end
    end
  end
end
