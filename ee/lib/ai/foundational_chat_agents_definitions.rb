# frozen_string_literal: true

module Ai
  module FoundationalChatAgentsDefinitions
    extend ActiveSupport::Concern

    ITEMS = [
      {
        id: 1,
        reference: 'chat',
        version: '',
        name: 'GitLab Duo Agent',
        description: "Duo is your general development assistant"
      },
      {
        id: 2,
        reference: 'duo_planner',
        version: 'experimental',
        name: 'Duo Planner',
        description: <<~DESCRIPTION
          GitLab Duo Planner is a Beta AI planning assistant that helps product teams explore, summarize,
          and reason about work in GitLab. It can analyze your work items to surface patterns, summarize context,
          and support planning conversations.
          This early version is read-only and focused on learning from how users engage with it.
          Your feedback will help shape future capabilities
          like creating or editing work items, prioritization assistance, and roadmap generation.
          Link to docs on how to engage
          with Duo Planner: https://docs.gitlab.com/user/duo_agent_platform/agents/foundational_agents/planner/
        DESCRIPTION
      },
      {
        id: 3,
        reference: 'security_analyst_agent',
        version: 'experimental',
        name: 'Security Analyst Agent',
        description: <<~DESCRIPTION
          The GitLab Security Analyst Agent is an AI-powered security expert designed to automate vulnerability
          management and security workflows within GitLab's Duo Agent Platform. It acts as a specialized AI team member
          that can autonomously analyze, triage, and remediate security vulnerabilities, reducing manual security tasks
          while ensuring critical exploitable vulnerabilities are immediately surfaced and addressed.
        DESCRIPTION
      }
    ].freeze
  end
end
