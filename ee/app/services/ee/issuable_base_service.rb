# frozen_string_literal: true

module EE
  module IssuableBaseService
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    private

    override :associations_before_update
    def associations_before_update(issuable)
      associations = super

      associations[:escalation_policy] = issuable.escalation_status&.policy if issuable.escalation_policies_available?
      associations[:approval_rules] = issuable.approval_rules.map(&:hook_attrs) if issuable.supports_approval_rules?

      associations
    end

    override :filter_params
    def filter_params(issuable)
      can_admin_issuable = can_admin_issuable?(issuable)

      unless can_admin_issuable && issuable.weight_available?
        params.delete(:weight)
      end

      unless can_admin_issuable && issuable.supports_health_status?
        params.delete(:health_status)
      end

      [:iteration, :sprint_id].each { |iteration_param| params.delete(iteration_param) } unless can_admin_issuable

      super
    end

    def update_task_event?
      strong_memoize(:update_task_event) do
        params.key?(:update_task)
      end
    end

    override :allowed_create_params
    def allowed_create_params(params)
      super(params).except(:epic)
    end

    override :allowed_update_params
    def allowed_update_params(params)
      super(params).except(:epic, :last_test_report_state)
    end
  end
end
