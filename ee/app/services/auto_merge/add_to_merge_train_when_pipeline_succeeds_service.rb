# frozen_string_literal: true

module AutoMerge
  class AddToMergeTrainWhenPipelineSucceedsService < AutoMerge::BaseService
    def execute(merge_request)
      super do
        SystemNoteService.add_to_merge_train_when_pipeline_succeeds(merge_request, project, current_user, merge_request.diff_head_pipeline.sha)
      end
    end

    def process(merge_request)
      return unless merge_request.diff_head_pipeline_success?

      merge_train_service = AutoMerge::MergeTrainService.new(project, merge_request.merge_user)

      return abort(merge_request, 'this merge request cannot be added to the merge train') unless merge_train_service.available_for?(merge_request)

      merge_train_service.execute(merge_request)
    end

    def cancel(merge_request)
      super do
        SystemNoteService.cancel_add_to_merge_train_when_pipeline_succeeds(merge_request, project, current_user)
      end
    end

    def abort(merge_request, reason)
      # If the merge request is already on a merge train, we need to destroy the car
      # i.e. If the target branch is deleted which causes an abort with this strategy,
      # after the pipeline succeeded and was added
      #
      if merge_request.merge_train_car
        AutoMerge::MergeTrainService.new(project, current_user).abort(merge_request, reason)
      # Before the pipeline succeeds and was added to the merge train
      else
        super do
          SystemNoteService.abort_add_to_merge_train_when_pipeline_succeeds(merge_request, project, current_user, reason)
        end
      end
    end

    def available_for?(merge_request)
      super do
        next false if ::Feature.enabled?(:merge_when_checks_pass_merge_train, merge_request.project)

        merge_request.project.merge_trains_enabled? &&
          merge_request.diff_head_pipeline_considered_in_progress?
      end
    end
  end
end
