# frozen_string_literal: true

module Ai
  module AdditionalContext
    CODE_SUGGESTIONS_CONTEXT_TYPES = { file: 'file', snippet: 'snippet' }.freeze
    DUO_CHAT_CONTEXT_CATEGORIES = { file: 'file', snippet: 'snippet' }.freeze

    MAX_BODY_SIZE = ::API::CodeSuggestions::MAX_BODY_SIZE
    MAX_CONTEXT_TYPE_SIZE = 255
  end
end
