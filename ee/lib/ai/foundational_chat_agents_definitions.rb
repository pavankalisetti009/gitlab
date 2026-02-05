# frozen_string_literal: true

module Ai
  module FoundationalChatAgentsDefinitions
    extend ActiveSupport::Concern

    ITEMS = [
      {
        id: 1,
        reference: 'chat',
        global_catalog_id: nil,
        version: '',
        name: 'GitLab Duo',
        avatar: 'gitlab-duo-agent.png',
        description: "Your general development assistant. Get help with code, planning,
        security, project management, and more."
      },
      {
        id: 2,
        reference: 'duo_planner',
        version: 'v1',
        name: 'Planner',
        global_catalog_id: 348,
        avatar: 'planner-agent.png',
        description: <<~DESCRIPTION
          Get help with planning and workflow management. Organize, edit, create, and track work more effectively in GitLab.
        DESCRIPTION
      },
      {
        id: 3,
        global_catalog_id: 356,
        reference: 'security_analyst_agent',
        version: 'v1',
        name: 'Security Analyst',
        avatar: 'security-agent.png',
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
        global_catalog_id: nil,
        version: 'v1',
        name: 'Data Analyst',
        avatar: 'analytics-agent.png',
        description: <<~DESCRIPTION
          Beta AI assistant for analyzing data in GitLab, powered by GLQL
        DESCRIPTION
      }
    ].freeze
  end
end
