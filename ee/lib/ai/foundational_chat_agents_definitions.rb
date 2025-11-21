# frozen_string_literal: true

module Ai
  module FoundationalChatAgentsDefinitions
    extend ActiveSupport::Concern

    ITEMS = [
      {
        id: 1,
        reference: 'chat',
        version: '',
        name: 'GitLab Duo',
        description: "Your general development assistant. Get help with code, planning,
        security, project management, and more."
      },
      {
        id: 2,
        reference: 'duo_planner',
        version: 'experimental',
        name: 'Planner',
        description: <<~DESCRIPTION
          Get help with planning and workflow management. Organize, prioritize, and track work
          more effectively in GitLab. The Planner Agent can analyze your work items to surface patterns,
          summarize context, and support planning conversations. This beta version is read-only and
          focused on learning from how you engage with it. Your feedback will help shape future capabilities
          like creating or editing work items, prioritization assistance, and roadmap generation.
          Learn more: https://docs.gitlab.com/user/duo_agent_platform/agents/foundational_agents/planner/
        DESCRIPTION
      },
      {
        id: 3,
        reference: 'security_analyst_agent',
        version: 'experimental',
        name: 'Security Analyst',
        description: <<~DESCRIPTION
          Automate vulnerability management and security workflows. The Security Analyst Agent acts as an
          AI team member that can autonomously analyze,
          triage, and remediate security vulnerabilities, reducing manual security tasks while ensuring
          critical exploitable vulnerabilities are immediately surfaced and addressed.
        DESCRIPTION
      },
      {
        id: 4,
        reference: 'analytics_agent',
        version: 'v1',
        name: 'Analytics Agent',
        description: <<~DESCRIPTION
          AI querying assistant that helps product teams explore, summarize, and share their analytical
          data in GitLab using GLQL queries
        DESCRIPTION
      }
    ].freeze
  end
end
