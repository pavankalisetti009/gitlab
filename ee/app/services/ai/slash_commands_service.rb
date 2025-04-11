# frozen_string_literal: true

module Ai
  class SlashCommandsService
    CONTROLLER_CONTEXTS = {
      'projects/issues' => :issue,
      'projects/jobs' => :job,
      'projects/security/vulnerabilities' => :vulnerability
    }.freeze

    def self.commands
      {
        base: [
          { name: '/help', description: _('Learn what Duo Chat can do.'), should_submit: true }
        ],
        issue: [
          { name: '/summarize_comments',
            description: _('Summarize the comments in the current issue.'),
            should_submit: true }
        ],
        job: [
          { name: '/troubleshoot',
            description: _('Troubleshoot failed CI/CD jobs with Root Cause Analysis.'),
            should_submit: true }
        ],
        vulnerability: [
          { name: '/vulnerability_explain',
            description: _('Explain current vulnerability.'),
            should_submit: true }
        ]
      }.freeze
    end

    def initialize(user, url)
      @user = user
      @url = url
      @route = ::Gitlab::Llm::Utils::RouteHelper.new(url)
    end

    def available_commands
      results = new_thread_commands
      results.concat(self.class.commands[:base])
      results.concat(context_commands)
    end

    private

    def new_thread_commands
      if Feature.enabled?(:duo_chat_multi_thread, @user)
        [
          { name: '/new', description: _('New chat conversation.'), should_submit: false }
        ]
      else
        [
          { name: '/reset', description: _('Reset conversation and ignore previous messages.'),
            should_submit: true },
          { name: '/clear', description: _('Delete all messages in the current conversation.'),
            should_submit: true }
        ]
      end
    end

    def context_commands
      context = determine_context
      return [] unless can_use_context_commands?(context)

      self.class.commands[context] || []
    end

    def can_use_context_commands?(context)
      return false unless has_duo_enterprise_access?

      case context
      when :issue then true
      when :job then can_access_job?
      when :vulnerability then can_access_vulnerability?
      else false
      end
    end

    def has_duo_enterprise_access?
      return false unless @route.exists?

      namespace = @route.namespace
      namespace && @user&.assigned_to_duo_enterprise?(namespace)
    end

    def can_access_job?
      record_exists?('jobs')
    end

    def can_access_vulnerability?
      record_exists?('vulnerabilities')
    end

    def determine_context
      return :unknown unless @route.exists?

      CONTROLLER_CONTEXTS[@route.controller] || :unknown
    end

    def record_exists?(resource)
      project = @route.project
      id = @route.id
      return false unless project && id

      case resource
      when 'jobs'
        project.builds.failed.id_in(id).exists?
      when 'vulnerabilities'
        project.vulnerabilities.sast.id_in(id).exists?
      end
    end
  end
end
