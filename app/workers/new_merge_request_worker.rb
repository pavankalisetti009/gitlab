# frozen_string_literal: true

class NewMergeRequestWorker
  include ApplicationWorker
  include NewIssuable

  data_consistency :always
  sidekiq_options retry: 3

  idempotent!
  deduplicate :until_executed

  feature_category :code_review_workflow
  urgency :high

  worker_resource_boundary :cpu
  weight 2

  def perform(merge_request_id, user_id)
    params = { merge_request_id: merge_request_id, user_id: user_id }
    xp = resume_covered_experience(**params)

    Gitlab::QueryLimiting.disable!('https://gitlab.com/gitlab-org/gitlab/-/issues/337182')

    return unless objects_found?(merge_request_id, user_id)
    return if issuable.prepared?

    MergeRequests::AfterCreateService
      .new(project: issuable.target_project, current_user: user)
      .execute(issuable)
  ensure
    xp&.complete(**params)
  end

  def issuable_class
    MergeRequest
  end

  private

  def resume_covered_experience(**context)
    return unless Feature.enabled?(:covered_experience_create_merge_request, Feature.current_request)

    Labkit::CoveredExperience.resume(:create_merge_request, **context)
  end
end

NewMergeRequestWorker.prepend_mod
