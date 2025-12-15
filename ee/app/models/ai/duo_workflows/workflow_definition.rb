# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowDefinition
      include ActiveRecord::FixedItemsModel::Model
      include GlobalID::Identification
      include Gitlab::Utils::StrongMemoize

      ITEMS = [
        {
          id: 1,
          name: "code_review/v1",
          description: "GitLab Code Review",
          foundational_flow_reference: "code_review/v1",
          ai_feature: "review_merge_request",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          triggers: []
        },
        {
          id: 2,
          name: "sast_fp_detection/v1",
          description: "GitLab SAST False Positive detection",
          foundational_flow_reference: "sast_fp_detection/v1",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          environment: "web",
          triggers: []
        },
        {
          id: 3,
          name: "resolve_sast_vulnerability/v1",
          description: "GitLab resolve SAST vulnerability",
          foundational_flow_reference: "resolve_sast_vulnerability/v1",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          environment: "web",
          triggers: []
        },
        {
          id: 4,
          name: "developer/v1",
          foundational_flow_reference: "developer/v1",
          description: "GitLab Duo developer",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          environment: "web",
          triggers: [::Ai::FlowTrigger::EVENT_TYPES[:assign]],
          avatar: "gitlab-duo-flow.png"
        },
        {
          id: 5,
          name: "fix_pipeline/v1",
          foundational_flow_reference: "fix_pipeline/v1",
          description: "GitLab pipeline troubleshooter",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          environment: "web",
          triggers: [],
          avatar: "fix-pipeline-flow.png"
        }
      ].freeze

      attribute :name, :string
      attribute :ai_feature, :string, default: "duo_agent_platform"
      attribute :agent_privileges, default: []
      attribute :pre_approved_agent_privileges, default: []
      attribute :allow_agent_to_request_user, :boolean, default: false
      attribute :environment, :string, default: "ambient"
      attribute :foundational_flow_reference, :string
      attribute :description, :string
      attribute :triggers, default: []
      attribute :avatar, :string

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

      def foundational_flow
        return if foundational_flow_reference.nil?

        Ai::Catalog::Item.with_foundational_flow_reference(foundational_flow_reference).first
      end
      strong_memoize_attr :foundational_flow

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
