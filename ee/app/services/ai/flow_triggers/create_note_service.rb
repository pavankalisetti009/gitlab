# frozen_string_literal: true

module Ai
  module FlowTriggers
    class CreateNoteService
      attr_reader :project, :resource, :author, :discussion

      def initialize(project:, resource:, author:, discussion: nil)
        @project = project
        @resource = resource
        @author = author
        @discussion = discussion
      end

      def execute(params)
        note = create_note

        response, workflow = yield(params.merge(discussion_id: note.discussion_id))

        update_note(note, response, workflow)

        response
      end

      private

      def create_note
        note = s_('AiFlowTriggers|🔄 Processing the request...')

        ::Notes::CreateService.new(
          project,
          author,
          note: note,
          noteable: resource,
          in_reply_to_discussion_id: discussion&.id
        ).execute
      end

      def update_note(note, response, workflow)
        updated_message =
          if response.success?
            link_start = format('<a href="%{url}" target="_blank" rel="noopener noreferrer">'.html_safe,
              url: "#{Gitlab::Routing.url_helpers.project_automate_agent_sessions_url(project)}/#{workflow.id}")
            # We already sanitize names, but as an added safety, it's a good idea to sanitize this input here as well.
            format(s_(
              "AiFlowTriggers|✅ %{flow_name} has started. You can view progress %{link_start}here%{link_end}."
            ), link_start: link_start, link_end: '</a>'.html_safe, flow_name: html_escape(author.name))
          else
            format(s_("AiFlowTriggers|❌ Could not start processing due to this error: %{error}"),
              error: response.message)
          end

        note.update(note: updated_message)
      end
    end
  end
end
