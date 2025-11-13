# frozen_string_literal: true

module SystemNotes # rubocop:disable Gitlab/BoundedContexts -- SystemNotes module already exists and holds the other services
  class AgentsService < ::SystemNotes::BaseService
    # Called when a new agent session is started
    #
    # session_id - The ID of the agent session
    # trigger_source - What triggered the session (default: 'User')
    # agent_name - Name of the agent (default: 'Duo Developer')
    #
    # Example Note text:
    #
    # "Duo Developer started session [123](session_url) triggered by Issue to merge request"
    #
    # Returns the created Note object
    def agent_session_started(session_id, trigger_source = 'User', agent_name = 'Duo Developer')
      session_link = create_session_link(session_id)

      body = "**#{agent_name}** started session #{session_link}"

      body += " triggered by #{trigger_source}" if trigger_source.present?

      create_note(NoteSummary.new(
        noteable,
        project,
        author,
        body,
        action: 'duo_agent_started'
      ))
    end

    # Called when a Duo agent session is completed
    #
    # session_id - The ID of the agent session
    # agent_name - Name of the agent (default: 'Duo Developer')
    #
    # Example Note text:
    #
    # "Duo Developer completed session [123](session_url)"
    #
    # Returns the created Note object
    def agent_session_completed(session_id, agent_name = 'Duo Developer')
      session_link = create_session_link(session_id)

      body = "**#{agent_name}** completed session #{session_link}"

      create_note(NoteSummary.new(
        noteable,
        project,
        author,
        body,
        action: 'duo_agent_completed'
      ))
    end

    # Called when a Duo agent session fails
    #
    # session_id - The ID of the agent session
    # reason - Optional reason for failure
    # agent_name - Name of the agent (default: 'Duo Developer')
    #
    # Example Note text:
    #
    # "Duo Developer session [123](session_url) failed"
    # "Duo Developer session [123](session_url) failed (dropped)"
    #
    # Returns the created Note object
    def agent_session_failed(session_id, reason = nil, agent_name = 'Duo Developer')
      session_link = create_session_link(session_id)

      body = "**#{agent_name}** session #{session_link} failed"

      body += " (#{reason})" if reason.present?

      create_note(NoteSummary.new(
        noteable,
        project,
        author,
        body,
        action: 'duo_agent_failed'
      ))
    end

    private

    def create_session_link(session_id)
      session_id = ERB::Util.html_escape(session_id)

      return session_id.to_s unless project

      session_url = "#{project.web_url}/-/automate/agent-sessions/#{session_id}"

      "[#{session_id}](#{session_url})"
    end
  end
end
