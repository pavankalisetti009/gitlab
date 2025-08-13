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

        response = yield(params.merge(discussion_id: note.discussion_id))

        update_note(note, response)

        response
      end

      private

      def create_note
        note = s_('AiFlowTriggers|🔄 Processing the request and starting the agent...')

        ::Notes::CreateService.new(
          project,
          author,
          note: note,
          noteable: resource,
          in_reply_to_discussion_id: discussion&.id
        ).execute
      end

      def update_note(note, response)
        updated_message =
          if response.success?
            link_start = format('<a href="%{url}" target="_blank" rel="noopener noreferrer">'.html_safe,
              url: response.payload.logs_url)
            format(s_(
              "AiFlowTriggers|✅ Agent has started. You can view the progress %{link_start}here%{link_end}."
            ), link_start: link_start, link_end: '</a>'.html_safe)
          else
            format(s_("AiFlowTriggers|❌ Could not start the agent due to this error: %{error}"),
              error: response.message)
          end

        note.update(note: updated_message)
      end
    end
  end
end
