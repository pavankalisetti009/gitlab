# frozen_string_literal: true

module Users
  class RecordAgentPlatformCalloutService < BaseGroupService
    def execute
      return ServiceResponse.error(message: 'User not authorized to request') unless authorized_to_request?

      group_callout = current_user.find_or_initialize_group_callout('duo_agent_platform_requested', group.id)
      return ServiceResponse.success(message: 'Access already requested') if group_callout.persisted?

      if group_callout.save
        ::NamespaceSetting.increment_counter(:duo_agent_platform_request_count, group.id)

        ServiceResponse.success
      else
        ServiceResponse.error(message: group_callout.errors.full_messages.to_sentence)
      end
    end

    private

    def authorized_to_request?
      Ability.allowed?(current_user, :read_namespace_via_membership, group)
    end
  end
end
