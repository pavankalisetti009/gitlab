# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- TODO refactor to use bounded context
module AutoMerge
  class AddToMergeTrainWhenChecksPassService < MergeTrains::BaseService
    extend Gitlab::Utils::Override

    def execute(merge_request)
      super do
        SystemNoteService.add_to_merge_train_when_checks_pass(merge_request, project, current_user,
          merge_request.diff_head_pipeline.sha)
      end
    end

    def process(merge_request)
      logger.info("Processing Automerge - AMTWCP")

      return if merge_request.has_ci_enabled? && !merge_request.diff_head_pipeline_success?

      logger.info("Pipeline Success - AMTWCP")

      return unless merge_request.mergeable?(skip_conflict_check: true)

      logger.info("Merge request mergeable - AMTWCP")

      merge_train_service = AutoMerge::MergeTrainService.new(project, merge_request.merge_user)

      unless merge_train_service.available_for?(merge_request)
        if Feature.enabled?(:auto_merge_train_elaborate_abort_msg, project)
          return abort(merge_request,
            process_abort_message(merge_train_service.availability_details(merge_request)))
        end

        return abort(merge_request, 'this merge request cannot be added to the merge train')
      end

      merge_train_service.execute(merge_request)
    end

    def cancel(merge_request)
      super do
        SystemNoteService.cancel_add_to_merge_train_when_checks_pass(merge_request, project, current_user)
      end
    end

    def abort(merge_request, reason)
      # If the merge request is already on a merge train, we need to destroy the car
      # i.e. If the target branch is deleted which causes an abort with this strategy,
      # after the pipeline succeeded and was added
      #
      if merge_request.merge_train_car
        AutoMerge::MergeTrainService.new(project, current_user).abort(merge_request, reason)
        # Before the pipeline checks pass and was added to the merge train
      else
        super do
          SystemNoteService.abort_add_to_merge_train_when_checks_pass(merge_request, project, current_user, reason)
        end
      end
    end

    def available_for?(merge_request)
      super do
        next false unless merge_request.has_ci_enabled?
        next false if merge_request.mergeable? && !merge_request.diff_head_pipeline_considered_in_progress?

        merge_request.project.merge_trains_enabled?
      end
    end

    override :availability_details
    def availability_details(merge_request)
      super do
        default_reason = AvailabilityCheck.new(unavailable_reason: :default)
        next default_reason unless merge_request.has_ci_enabled?
        next default_reason if merge_request.mergeable? && !merge_request.diff_head_pipeline_considered_in_progress?

        unless merge_request.project.merge_trains_enabled?
          next AvailabilityCheck.new(unavailable_reason: :merge_trains_disabled)
        end

        AvailabilityCheck.new(unavailable_reason: nil)
      end
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
