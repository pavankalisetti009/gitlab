# frozen_string_literal: true

module Users
  class RecordAgentPlatformCalloutService < BaseGroupService
    def execute
      return ServiceResponse.error(message: 'User not authorized to request') unless authorized_to_request?

      @callout = current_user.find_or_initialize_group_callout('duo_agent_platform_requested', group.id)
      return ServiceResponse.success(message: 'Access already requested') if callout.persisted?

      if callout.save
        ::NamespaceSetting.increment_counter(:duo_agent_platform_request_count, group.id)

        ServiceResponse.success
      else
        log_error
        ServiceResponse.error(message: 'Failed to request Duo Agent Platform')
      end
    end

    private

    def authorized_to_request?
      Ability.allowed?(current_user, :read_namespace_via_membership, group)
    end

    attr_reader :callout

    def log_error
      error = StandardError.new(callout.errors.full_messages.to_sentence)
      ::Gitlab::ErrorTracking.track_exception(error)
    end
  end
end
