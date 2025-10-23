# frozen_string_literal: true

module Vulnerabilities
  module Flags
    class UpdateAiDetectionService
      include Gitlab::Allowable

      AI_SAST_FP_DETECTION_ORIGIN = 'ai_sast_fp_detection'

      def initialize(user, vulnerability, params)
        @user = user
        @vulnerability = vulnerability
        @params = params
        @project = vulnerability&.project
      end

      def execute
        return ServiceResponse.error(message: 'Vulnerability not found') unless vulnerability
        return ServiceResponse.error(message: 'Unauthorized') unless authorized?
        return ServiceResponse.error(message: 'No current finding available') unless current_finding

        update_flag
      end

      private

      attr_reader :user, :vulnerability, :params, :project

      def authorized?
        project && can?(user, :read_vulnerability, project)
      end

      def current_finding
        # currently vulnerabilities only have a single finding but this is poised to change in the future
        @current_finding ||= vulnerability&.last_finding
      end

      def find_or_initialize_flag
        # rubocop:disable CodeReuse/ActiveRecord -- Need to instantiate a new record here if none exist yet
        current_finding.vulnerability_flags.find_or_initialize_by(
          flag_type: :false_positive,
          origin: AI_SAST_FP_DETECTION_ORIGIN
        )
        # rubocop:enable CodeReuse/ActiveRecord
      end

      def flag
        @flag ||= find_or_initialize_flag
      end

      def update_flag
        flag.assign_attributes(
          description: params[:description] || flag.description,
          confidence_score: normalize_confidence_score(params[:confidence_score]),
          project_id: project.id
        )

        if flag.save
          ServiceResponse.success(payload: { flag: flag, is_new_flag: flag.saved_change_to_id? })
        else
          ServiceResponse.error(message: flag.errors.full_messages.join(', '))
        end
      end

      def normalize_confidence_score(score)
        # Convert 0-100 range to 0.0-1.0 range, default to 0.0 on nil
        score.to_f / 100.0
      end
    end
  end
end
