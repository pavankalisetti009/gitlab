# frozen_string_literal: true

module Ai
  module FoundationalChatAgentsDefinitions
    extend ActiveSupport::Concern

    ITEMS = [
      {
        id: 1,
        reference: 'chat',
        version: '',
        name: 'GitLab Duo Agent',
        description: "Duo is your general development assistant"
      }
    ].freeze
  end
end
