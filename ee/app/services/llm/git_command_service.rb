# frozen_string_literal: true

module Llm
  class GitCommandService < BaseService
    TEMPERATURE = 0.4
    INPUT_CONTENT_LIMIT = 300
    MAX_RESPONSE_TOKENS = 300

    def valid?
      options[:prompt].size < INPUT_CONTENT_LIMIT &&
        user.can?(:access_glab_ask_git_command)
    end

    private

    def ai_action
      :glab_ask_git_command
    end

    def perform
      response =
        ::Gitlab::Llm::Anthropic::Client
          .new(user, unit_primitive: 'glab_ask_git_command')
          .messages_complete(
            **::Gitlab::Llm::Templates::GitCommand.new(options[:prompt]).to_prompt
          )

      response_modifier = ::Gitlab::Llm::Anthropic::ResponseModifiers::GitCommand.new(response)

      success(response_modifier.response_body)
    end
  end
end
