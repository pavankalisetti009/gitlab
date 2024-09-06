# frozen_string_literal: true

module Types
  module Ai
    class AdditionalContextCategoryEnum < BaseEnum
      graphql_name 'AiAdditionalContextCategory'
      description 'The category of the additional context'

      ::CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages::CONTENT_TYPES.each_value do |category|
        value category.upcase, description: "#{category.capitalize} content category.", value: category
      end
    end
  end
end
