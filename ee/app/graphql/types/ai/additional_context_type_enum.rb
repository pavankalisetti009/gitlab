# frozen_string_literal: true

module Types
  module Ai
    class AdditionalContextTypeEnum < BaseEnum
      graphql_name 'AiAdditionalContextType'
      description 'The type of additional context'

      ::CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages::CONTENT_TYPES.each_value do |type|
        value type.upcase, description: "#{type.capitalize} content type.", value: type
      end
    end
  end
end
