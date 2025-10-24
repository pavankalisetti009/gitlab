# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowDefinition
      include ActiveRecord::FixedItemsModel::Model
      include GlobalID::Identification

      ITEMS = [
        {
          id: 1,
          name: "code_review/v1",
          ai_feature: "review_merge_request",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ]
        },
        {
          id: 2,
          name: "sast_fp_detection/v1",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          environment: "web"
        }
      ].freeze

      attribute :name, :string
      attribute :ai_feature, :string, default: "duo_agent_platform"
      attribute :agent_privileges, default: []
      attribute :pre_approved_agent_privileges, default: []
      attribute :allow_agent_to_request_user, :boolean, default: false
      attribute :environment, :string, default: "ambient"

      validates :name, :ai_feature, presence: true

      def self.[](name)
        find_by(name: name)&.tap do |definition|
          definition.agent_privileges = definition.pre_approved_agent_privileges if definition.agent_privileges.empty?
        end
      end

      def agent_privileges
        privileges = super

        return pre_approved_agent_privileges if privileges.empty?

        privileges
      end

      def agent_privileges=(value)
        super(Array(value).map { |v| Integer(v) })
      end

      def pre_approved_agent_privileges=(value)
        super(Array(value).map { |v| Integer(v) })
      end

      def as_json(_options = {})
        {
          workflow_definition: name,
          agent_privileges: agent_privileges,
          pre_approved_agent_privileges: pre_approved_agent_privileges,
          allow_agent_to_request_user: allow_agent_to_request_user,
          environment: environment
        }
      end
    end
  end
end
