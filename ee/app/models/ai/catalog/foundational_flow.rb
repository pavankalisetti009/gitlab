# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      include ActiveRecord::FixedItemsModel::Model
      include GlobalID::Identification
      include Gitlab::Utils::StrongMemoize

      ITEMS = [
        {
          id: 1,
          name: "code_review/v1",
          display_name: "Code Review",
          description: "The Code Review Flow helps you streamline code reviews with agentic AI.",
          avatar: "code-review-flow.png",
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
          display_name: "SAST False Positive Detection",
          description: "SAST false positive detection automatically analyzes critical SAST vulnerabilities.",
          avatar: "security-flow.png",
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
          display_name: "Resolve SAST Vulnerability",
          workflow_definition: "resolve_sast_vulnerability/v1",
          description: "GitLab resolve SAST vulnerability",
          avatar: "security-flow.png",
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
          display_name: "Developer",
          foundational_flow_reference: "developer/v1",
          description:
            "The Developer Flow streamlines the process of converting issues into actionable merge requests.",
          avatar: "gitlab-duo-flow.png",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          environment: "web",
          triggers: [::Ai::FlowTrigger::EVENT_TYPES[:assign]]
        },
        {
          id: 5,
          name: "fix_pipeline/v1",
          display_name: "Fix CI/CD pipeline",
          foundational_flow_reference: "fix_pipeline/v1",
          description: "The Fix CI/CD Pipeline Flow helps you automatically diagnose and fix issues in your GitLab
CI/CD pipeline.",
          avatar: "fix-pipeline-flow.png",
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
          id: 6,
          name: "convert_to_gl_ci/v1",
          display_name: "Convert to GitLab CI/CD",
          foundational_flow_reference: "convert_to_gl_ci/v1",
          description: "The Convert to GitLab CI/CD Flow helps you migrate your Jenkins pipelines to GitLab CI/CD.",
          avatar: "convert-ci-flow.png",
          pre_approved_agent_privileges: [
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
          ],
          environment: "web",
          triggers: []
        }
      ].freeze

      attribute :workflow_definition, :string
      attribute :name, :string
      attribute :display_name, :string
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

      def self.[](key)
        definition = find_by(name: key) || find_by(display_name: key)

        definition&.tap do |def_obj|
          def_obj.agent_privileges = def_obj.pre_approved_agent_privileges if def_obj.agent_privileges.empty?
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

      def catalog_item
        return if foundational_flow_reference.nil?

        Ai::Catalog::Item.with_foundational_flow_reference(foundational_flow_reference).first
      end
      strong_memoize_attr :catalog_item
    end
  end
end
