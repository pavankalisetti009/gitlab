# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Workflow < ::ApplicationRecord
      include Gitlab::SQL::Pattern
      include FromUnion
      include EachBatch
      include Sortable

      self.table_name = :duo_workflows_workflows

      belongs_to :user
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true
      belongs_to :ai_catalog_item_version, optional: true, class_name: 'Ai::Catalog::ItemVersion'

      has_many :checkpoints, class_name: 'Ai::DuoWorkflows::Checkpoint'
      has_many :checkpoint_writes, class_name: 'Ai::DuoWorkflows::CheckpointWrite'
      has_many :events, class_name: 'Ai::DuoWorkflows::Event'
      has_many :workflows_workloads, class_name: 'Ai::DuoWorkflows::WorkflowsWorkload'
      has_many :workloads, through: :workflows_workloads, disable_joins: true
      has_many :vulnerability_triggered_workflows, class_name: '::Vulnerabilities::TriggeredWorkflow'

      validates :status, presence: true
      validates :goal, length: { maximum: 16_384 }
      validates :image, length: { maximum: 2048 }, allow_blank: true

      validate :only_known_agent_priviliges
      validate :only_known_pre_approved_agent_privileges
      validate :pre_approved_privileges_included_in_agent_privileges, on: :create

      # `ide` is deprecated in favor of `chat`
      # `web` is deprecated in favor of `ambient`
      enum :environment, { ide: 1, web: 2, chat_partial: 3, chat: 4, ambient: 5 }

      scope :for_user_with_id!, ->(user_id, id) { find_by!(user_id: user_id, id: id) }
      scope :for_user, ->(user_id) { where(user_id: user_id) }
      scope :for_project, ->(project) { where(project: project) }
      scope :stale_since, ->(time) { where(updated_at: ...time).order(updated_at: :asc, id: :asc) }
      scope :with_workflow_definition, ->(definition) { where(workflow_definition: definition) }
      scope :without_workflow_definition, ->(definition) { where.not(workflow_definition: definition) }
      scope :with_environment, ->(environment) { where(environment: environment) }
      scope :from_pipeline, -> { where.not(workflow_definition: :chat).with_environment(ENVIRONMENTS_FROM_PIPELINE) }
      scope :in_status_group, ->(status_group) do
        statuses_in_group = GROUPED_STATUSES.fetch(status_group.to_sym, [])

        if statuses_in_group.empty?
          none
        else
          state_machine_states = state_machines[:status].states
          status_db_values = statuses_in_group.map { |status| state_machine_states[status.to_sym].value }
          where(status: status_db_values)
        end
      end
      scope :order_by_status, ->(direction) do
        status_order_expression = Arel::Nodes::NamedFunction.new(
          'ARRAY_POSITION',
          [
            Arel.sql("ARRAY#{ordered_statuses}::smallint[]"),
            arel_table[:status]
          ]
        )

        final_order_expression =
          if direction.to_s.casecmp?('desc')
            status_order_expression.desc
          else
            status_order_expression.asc
          end

        order = Gitlab::Pagination::Keyset::Order.build([
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'status',
            column_expression: status_order_expression,
            order_expression: final_order_expression,
            order_direction: direction,
            nullable: :not_nullable
          ),
          # Tie-breaker for deterministic ordering
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'id',
            order_expression: arel_table[:id].desc,
            nullable: :not_nullable
          )
        ])

        reorder(order)
      end

      TARGET_STATUSES = {
        start: :running,
        pause: :paused,
        require_input: :input_required,
        require_plan_approval: :plan_approval_required,
        require_tool_call_approval: :tool_call_approval_required,
        resume: :running,
        retry: :running,
        finish: :finished,
        drop: :failed,
        stop: :stopped
      }.freeze

      GROUPED_STATUSES = {
        active: [:created, :running],
        paused: [:paused],
        awaiting_input: [:input_required, :plan_approval_required, :tool_call_approval_required],
        completed: [:finished],
        failed: [:failed],
        canceled: [:stopped]
      }.freeze

      ENVIRONMENTS_FROM_PIPELINE = %w[web ambient].freeze
      ENVIRONMENTS_DEPRECATIONS = {
        'ide' => 'chat',
        'web' => 'ambient'
      }.freeze

      class AgentPrivileges
        READ_WRITE_FILES  = 1
        READ_ONLY_GITLAB  = 2
        READ_WRITE_GITLAB = 3
        RUN_COMMANDS      = 4
        USE_GIT           = 5
        RUN_MCP_TOOLS     = 6

        ALL_PRIVILEGES = {
          READ_WRITE_FILES => {
            name: "read_write_files",
            description: "Allow local filesystem read/write access"
          }.freeze,
          READ_ONLY_GITLAB => {
            name: "read_only_gitlab",
            description: "Allow read only access to GitLab APIs"
          }.freeze,
          READ_WRITE_GITLAB => {
            name: "read_write_gitlab",
            description: "Allow write access to GitLab APIs"
          }.freeze,
          RUN_COMMANDS => {
            name: "run_commands",
            description: "Allow running any commands"
          }.freeze,
          USE_GIT => {
            name: "use_git",
            description: "Allow git commits, push and other git commands"
          }.freeze,
          RUN_MCP_TOOLS => {
            name: "run_mcp_tools",
            description: "Allow running MCP tools"
          }.freeze
        }.freeze

        DEFAULT_PRIVILEGES = [
          READ_WRITE_FILES,
          READ_ONLY_GITLAB
        ].freeze
      end

      def self.target_status_for_event(status_event)
        TARGET_STATUSES[status_event]
      end

      def self.ordered_statuses
        statuses_values = state_machines[:status].states

        GROUPED_STATUSES.flat_map do |_group, statuses|
          statuses.map do |status|
            statuses_values.fetch(status).value
          end
        end
      end

      def only_known_agent_priviliges
        self.agent_privileges ||= AgentPrivileges::DEFAULT_PRIVILEGES

        agent_privileges.each do |privilege|
          unless AgentPrivileges::ALL_PRIVILEGES.key?(privilege)
            errors.add(:agent_privileges, "contains an invalid value #{privilege}")
          end
        end
      end

      def chat?
        workflow_definition == 'chat'
      end

      def from_pipeline?
        return false if chat?

        environment.in?(ENVIRONMENTS_FROM_PIPELINE)
      end

      def archived?
        created_at <= CHECKPOINT_RETENTION_DAYS.days.ago
      end

      def stalled?
        !created? && !checkpoints.exists?
      end

      def last_executor_logs_url
        last_workload&.logs_url
      end

      def last_workload
        @last_workload ||= workloads.order(created_at: :desc).first
      end

      def project_level?
        project_id.present?
      end

      def namespace_level?
        namespace_id.present?
      end

      def resource_parent
        project || namespace
      end

      def mcp_enabled?
        return true if resource_parent.root_ancestor.duo_workflow_mcp_enabled

        false
      end

      def status_group
        GROUPED_STATUSES.find do |_group, statuses|
          statuses.include?(status_name)
        end&.first
      end

      private

      def only_known_pre_approved_agent_privileges
        return if pre_approved_agent_privileges.nil?

        pre_approved_agent_privileges.each do |privilege|
          next if AgentPrivileges::ALL_PRIVILEGES.key?(privilege)

          errors.add(:pre_approved_agent_privileges, "contains an invalid value #{privilege}")
        end
      end

      def pre_approved_privileges_included_in_agent_privileges
        # both columns will use db default values which are equal
        return if pre_approved_agent_privileges.nil? && agent_privileges.nil?

        pre_approved_privileges_with_defaults = pre_approved_agent_privileges || AgentPrivileges::DEFAULT_PRIVILEGES
        agent_privileges_with_defaults = agent_privileges || AgentPrivileges::DEFAULT_PRIVILEGES

        pre_approved_privileges_with_defaults.each do |privilege|
          next if agent_privileges_with_defaults.include?(privilege)

          errors.add(
            :pre_approved_agent_privileges,
            "contains privilege #{privilege} not present in agent_privileges"
          )
        end
      end

      state_machine :status, initial: :created do
        event :start do
          transition created: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:start)
        end

        event :pause do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:pause)
        end

        event :require_input do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:require_input)
        end

        event :require_plan_approval do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:require_plan_approval)
        end

        event :require_tool_call_approval do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:require_tool_call_approval)
        end

        event :resume do
          transition [
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:resume)
        end

        event :retry do
          transition [:running, :stopped, :failed] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:retry)
        end

        event :finish do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:finish)
        end

        event :drop do
          transition [
            :created,
            :running,
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:drop)
        end

        event :stop do
          transition [
            :created,
            :running,
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:stop)
        end

        state :created, value: 0
        state :running, value: 1
        state :paused, value: 2
        state :finished, value: 3
        state :failed, value: 4
        state :stopped, value: 5
        state :input_required, value: 6
        state :plan_approval_required, value: 7
        state :tool_call_approval_required, value: 8
      end
    end
  end
end
