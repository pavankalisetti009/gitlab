# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module SummarizeComments
          class Executor < SlashCommandTool
            include Gitlab::Utils::StrongMemoize
            prepend Concerns::UseAiGatewayAgentPrompt

            NAME = "SummarizeComments"
            DESCRIPTION = "This tool is useful when you need to create a summary of all notes, " \
                          "comments or discussions on a given, identified resource."
            EXAMPLE =
              <<~PROMPT
                Question: Please summarize the http://gitlab.example/ai/test/-/issues/1 issue in the bullet points
                Picked tools: First: "IssueReader" tool, second: "SummarizeComments" tool.
                Reason: There is issue identifier in the question, so you need to use "IssueReader" tool.
                Once the issue is identified, you should use "SummarizeComments" tool to summarize the issue.
                For the final answer, please rewrite it into the bullet points.
              PROMPT

            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::Anthropic
            }.freeze

            SYSTEM_PROMPT = Utils::Prompt.as_system(
              <<~PROMPT
              You are an assistant that extracts the most important information from the comments in maximum 10 bullet points.
              PROMPT
            )

            USER_PROMPT = Utils::Prompt.as_user(
              <<~PROMPT
              Each comment is wrapped in a <comment> tag.

              Desired markdown format:
              **<summary_title>**
              - <bullet_point>
              - <bullet_point>
              - <bullet_point>
              - ...

              %<notes_content>s

              Focus on extracting information related to one another and that are the majority of the content.
              Ignore phrases that are not connected to others.
              Do not specify what you are ignoring.
              Do not answer questions.
              PROMPT
            )

            PROMPT_TEMPLATE = [
              SYSTEM_PROMPT,
              USER_PROMPT,
              Utils::Prompt.as_assistant("")
            ].freeze

            SLASH_COMMANDS = {
              '/summarize_comments' => {
                description: 'Summarize issue comments.',
                selected_code_without_input_instruction: 'Summarize issue comments.',
                selected_code_with_input_instruction: "Summary of issue comments. Input: %<input>s."
              }
            }.freeze

            def self.slash_commands
              SLASH_COMMANDS
            end

            def perform
              error_message = _("This resource has no comments to summarize") unless notes.any?

              return error_with_message(error_message) if error_message

              super
            end

            traceable :perform, run_type: 'tool'

            private

            def notes_to_summarize
              notes_content = +""
              input_content_limit = provider_prompt_class::MAX_CHARACTERS - PROMPT_TEMPLATE.size
              notes.each_batch do |batch|
                batch.pluck(:id, :note).each do |note| # rubocop: disable CodeReuse/ActiveRecord
                  break notes_content if notes_content.size + note[1].size >= input_content_limit

                  notes_content << (format("<comment>%<note>s</comment>", note: note[1]))
                end
              end

              notes_content
            end

            def notes
              NotesFinder.new(context.current_user, target: resource).execute.by_humans
            end
            strong_memoize_attr :notes

            def command_options
              {
                notes_content: notes_to_summarize
              }
            end

            def can_summarize?
              ability = Ability.allowed?(context.current_user, :summarize_comments, context.resource)
              log_conditional_info(context.current_user,
                message: "Supported Issuable Typees Ability Allowed",
                event_name: 'permission',
                ai_component: 'feature',
                allowed: ability)

              ::Llm::GenerateSummaryService::SUPPORTED_ISSUABLE_TYPES.include?(resource.to_ability_name) &&
                ability
            end

            def authorize
              can_summarize? && Utils::ChatAuthorizer.context(context: context).allowed?
            end

            def resource
              @resource ||= context.resource
            end

            def unit_primitive
              'summarize_comments'
            end

            def ai_request
              ::Gitlab::Llm::Chain::Requests::AiGateway.new(context.current_user, service_name: :summarize_comments,
                tracking_context: tracking_context)
            end

            def tracking_context
              {
                request_id: context.request_id,
                action: unit_primitive
              }
            end
          end
        end
      end
    end
  end
end
