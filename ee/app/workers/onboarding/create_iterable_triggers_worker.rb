# frozen_string_literal: true

module Onboarding
  class CreateIterableTriggersWorker # rubocop:disable Scalability/IdempotentWorker -- Don't rerun, else mass iterables created
    include ApplicationWorker

    data_consistency :delayed

    # this worker calls `Onboarding::CreateIterableTriggerWorker`,
    # which calls `Onboarding::CreateIterableTriggerService`, which in turn makes
    # a HTTP POST request to ::Gitlab::SubscriptionPortal::SUBSCRIPTIONS_URL
    worker_has_external_dependencies!

    feature_category :onboarding

    def perform(namespace_id, user_ids)
      # Deprecating as per https://docs.gitlab.com/ee/development/sidekiq/compatibility_across_updates.html#in-the-first-minor-release
      # Continue deprecation in https://gitlab.com/gitlab-org/gitlab/-/issues/497157
    end
  end
end
