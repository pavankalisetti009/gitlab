# frozen_string_literal: true

module AuditEvents
  class BulkDeleteRunnersAuditEventService < ::AuditEventService
    # Logs an audit event related to a bulk runner delete event
    #
    # @param [Array[Ci::Runner]] runners
    # @param [User] current_user: the User initiating the operation
    def initialize(runners, current_user)
      @runners = runners.to_a

      details = {
        custom_message: message,
        errors: @runners.filter_map { |runner| runner.errors.full_messages.presence }.join(', ').presence,
        runner_ids: @runners.map(&:id),
        runner_short_shas: @runners.map(&:short_sha)
      }.compact

      super(current_user, current_user, details)
    end

    def track_event
      security_event
    end

    private

    def message
      runner_short_shas = @runners.map(&:short_sha)

      "Deleted CI runners in bulk. Runner tokens: [#{runner_short_shas.join(', ')}]"
    end
  end
end
