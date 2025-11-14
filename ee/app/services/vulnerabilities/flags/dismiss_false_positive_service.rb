# frozen_string_literal: true

module Vulnerabilities
  module Flags
    class DismissFalsePositiveService
      include Gitlab::Allowable

      MANUAL_ORIGIN_PREFIX = 'manual'

      def initialize(user, vulnerability)
        @user = user
        @vulnerability = vulnerability
        @project = vulnerability&.project
      end

      def execute
        return ServiceResponse.error(message: 'Vulnerability not found') unless vulnerability
        return ServiceResponse.error(message: 'Unauthorized') unless authorized?
        return ServiceResponse.error(message: 'No current finding available') unless current_finding
        return ServiceResponse.error(message: 'No vulnerability flag available to dismiss') unless can_dismiss_flag?

        create_new_flag
      end

      private

      attr_reader :user, :vulnerability, :project

      def authorized?
        project && can?(user, :admin_vulnerability, project)
      end

      def current_finding
        # currently vulnerabilities only have a single finding but this is poised to change in the future
        @current_finding ||= vulnerability&.last_finding
      end

      def create_new_flag
        flag = current_finding.vulnerability_flags.build(
          flag_type: :false_positive,
          origin: unique_manual_origin,
          confidence_score: 0.0,
          project_id: project.id,
          description: 'Manually dismissed as false positive'
        )

        if flag.save
          ServiceResponse.success(payload: { flag: flag, is_new_flag: true })
        else
          ServiceResponse.error(message: flag.errors.full_messages.join(', '))
        end
      end

      def unique_manual_origin
        "#{MANUAL_ORIGIN_PREFIX}_#{Time.current.to_f}_#{SecureRandom.hex(4)}"
      end

      def can_dismiss_flag?
        # avoid creating dismissal record if no record exists
        # or we do not mark vuilnerability as false positive
        latest_flag = current_finding.vulnerability_flags&.last
        return false unless latest_flag&.confidence_score

        latest_flag.confidence_score > 0.0
      end
    end
  end
end
