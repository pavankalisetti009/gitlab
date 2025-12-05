# frozen_string_literal: true

module SystemNotes # rubocop:disable Gitlab/BoundedContexts -- SystemNotes module already exists and holds the other services
  class AgentsService < ::SystemNotes::BaseService
    # Called when a new agent session is started
    #
    # session_id - The ID of the agent session
    # trigger_source - Who/what triggered the session. Can be a User object or a String (default: 'User')
    #
    # Example Note text:
    #
    # "started session [123](session_url) triggered by [Jane Doe](user_profile_url)"
    #
    # Returns the created Note object
    def agent_session_started(session_id, trigger_source)
      session_link = create_session_link(session_id)
      trigger_source_reference = format_trigger_source(trigger_source)

      body = "started session #{session_link}"

      body += " triggered by #{trigger_source_reference}" if trigger_source.present?

      create_note(NoteSummary.new(
        noteable,
        project,
        agent_author,
        body,
        action: 'duo_agent_started'
      ))
    end

    # Called when a Duo agent session is completed
    #
    # session_id - The ID of the agent session
    #
    # Example Note text:
    #
    # "completed session [123](session_url)"
    #
    # Returns the created Note object
    def agent_session_completed(session_id)
      session_link = create_session_link(session_id)

      body = "completed session #{session_link}"

      create_note(NoteSummary.new(
        noteable,
        project,
        agent_author,
        body,
        action: 'duo_agent_completed'
      ))
    end

    # Called when a Duo agent session fails
    #
    # session_id - The ID of the agent session
    # reason - Optional reason for failure
    #
    # Example Note text:
    #
    # "session [123](session_url) failed"
    # "session [123](session_url) failed (dropped)"
    #
    # Returns the created Note object
    def agent_session_failed(session_id, reason = nil)
      session_link = create_session_link(session_id)

      body = "session #{session_link} failed"

      body += " (#{reason})" if reason.present?

      create_note(NoteSummary.new(
        noteable,
        project,
        agent_author,
        body,
        action: 'duo_agent_failed'
      ))
    end

    private

    def agent_author
      Ai::Setting.instance.duo_workflow_service_account_user
    end

    def create_session_link(session_id)
      session_id = ERB::Util.html_escape(session_id)

      return session_id.to_s unless project

      session_url = "#{project.web_url}/-/automate/agent-sessions/#{session_id}"

      "[#{session_id}](#{session_url})"
    end

    # Formats a trigger source into a markdown link or escaped string.
    #
    # @param trigger_source [User, String] The trigger source to format
    # @return [String] Markdown link for User objects, escaped string otherwise
    #
    # Examples:
    #   format_trigger_source(user)     # => "[Jane Doe](https://example.com/jdoe)"
    #   format_trigger_source("agent") # => "agent"
    def format_trigger_source(trigger_source)
      if trigger_source.is_a?(User)
        user_name_escaped = ERB::Util.html_escape(trigger_source.name)
        user_profile_url = "#{Gitlab.config.gitlab.url}/#{trigger_source.username}"

        "[#{user_name_escaped}](#{user_profile_url})"
      else
        ERB::Util.html_escape(trigger_source.to_s)
      end
    end
  end
end
