# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module TroubleshootJob
          class Executor < SlashCommandTool
            extend ::Gitlab::Utils::Override
            include Concerns::AiDependent
            include ::Gitlab::Utils::StrongMemoize

            # We use 1 Charater per 1 Token because we can't copy the tokenizer logic easily
            # So we go lower the characters per token to compensate for that.
            # For more context see: https://github.com/javirandor/anthropic-tokenizer and
            # https://gitlab.com/gitlab-org/gitlab/-/issues/474146
            APPROX_MAX_INPUT_CHARS = 100_000

            NAME = 'TroubleshootJob'
            RESOURCE_NAME = 'Ci::Build'
            HUMAN_NAME = 'Troubleshoot Job'
            DESCRIPTION = 'Useful tool to troubleshoot job-related issues.'
            EXAMPLE = "Question: My job is failing with an error. How can I fix it and figure out why it failed? " \
              'Picked tools: "TroubleshootJob" tool. ' \
              'Reason: The question is about troubleshooting a job issue. "TroubleshootJob" tool ' \
              'can process this question.'
            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic
            }.freeze

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                  You are a Software engineer's or DevOps engineer's Assistant.
                  You can explain the root cause of a GitLab CI verification job code failure from the job log.
                  %<language_info>s
                PROMPT
              ),
              Utils::Prompt.as_user(
                <<~PROMPT.chomp
                  Below are the job logs surrounded by the xml tag: <log>

                  <log>
                    %<selected_text>s
                  <log>

                  %<input>s

                  Think step by step and try to determine why the job failed and explain it so that
                  any Software engineer could understand the root cause of the failure.
                  Add a heading where the explanation of the failure is under a section heading
                  of H4 with the name "Root cause of failure".
                  Please provide an example fix under the heading "Example Fix". The header
                  "Example Fix" should be set with a section heading of H4.
                  Any code blocks in response should be formatted in markdown.
                PROMPT
              )
            ].freeze

            SLASH_COMMANDS = {
              '/troubleshoot' => {
                description: 'Troubleshoot a job based on the logs.',
                instruction: 'Troubleshoot the job log.',
                instruction_with_input: "Troubleshoot the job log. Input: %<input>s."
              }
            }.freeze

            def self.slash_commands
              SLASH_COMMANDS
            end

            override :perform
            def perform
              error_message = if !job.failed?
                                _('This command is used for troubleshooting jobs and can only be invoked from ' \
                                  'a failed job log page.')
                              elsif !job.trace.exist?
                                _('There is no job log to troubleshoot.')
                              end

              return error_with_message(error_message) if error_message

              super
            end

            private

            def unit_primitive
              'troubleshoot_job'
            end

            def ai_request
              ::Gitlab::Llm::Chain::Requests::AiGateway.new(context.current_user, service_name: :troubleshoot_job,
                tracking_context: tracking_context)
            end

            def tracking_context
              {
                request_id: context.request_id,
                action: unit_primitive
              }
            end

            def selected_text_options
              {
                selected_text: truncated_job_log,
                language_info: language_info
              }
            end

            def job_log
              # Line limit should be reworked based on
              # the results of the prompt library and prompt engineering.
              # 1000*100/4
              # 1000 lines, ~100 char per line (can be more), ~4 tokens per character
              # ~25000 tokens
              job.trace.raw(last_lines: 1000)
            end
            strong_memoize_attr :job_log

            def truncated_job_log
              log_size_allowed = APPROX_MAX_INPUT_CHARS - prompt_size_without_log
              job_log.last(log_size_allowed)
            end

            def user_prompt
              PROMPT_TEMPLATE[1][1]
            end

            def prompt_size_without_log
              user_prompt.size
            end

            def job
              context.resource
            end
            strong_memoize_attr :job

            def authorize
              context.current_user.can?(:troubleshoot_job_with_ai, job)
            end

            def resource_name
              RESOURCE_NAME
            end

            # Detects what code is used in the project
            # example return value:  "The repository code is written in Go, Ruby, Makefile, Shell and Dockerfile."
            def language_info
              language_names = job.project.repository_languages.map(&:name)
              return '' if language_names.empty?

              last_language = language_names.pop
              languages_comma_seperated = language_names.join(', ')

              if language_names.size >= 1
                "The repository code is written in #{languages_comma_seperated} and #{last_language}."
              else
                "The repository code is written in #{last_language}."
              end
            end
          end
        end
      end
    end
  end
end
