# frozen_string_literal: true

module Onboarding
  class AddOnSeatAssignmentIterableTriggerWorker # rubocop:disable Scalability/IdempotentWorker -- Don't rerun, else mass iterables created
    include ApplicationWorker

    data_consistency :delayed

    # this worker calls `Onboarding::CreateIterableTriggerWorker`,
    # which calls `Onboarding::CreateIterableTriggerService`, which in turn makes
    # a HTTP POST request to ::Gitlab::SubscriptionPortal::SUBSCRIPTIONS_URL
    worker_has_external_dependencies!

    feature_category :onboarding

    # step 1 in adding another parameter:
    # https://docs.gitlab.com/ee/development/sidekiq/compatibility_across_updates.html#parameter-hash
    def perform(namespace_id, user_ids, params = {})
      @namespace = Namespace.find_by_id(namespace_id)
      return unless @namespace.present?

      @params = params

      User.left_join_user_detail.id_in(user_ids).find_each do |user|
        Onboarding::CreateIterableTriggerWorker.perform_async(user_iterable_params(user).stringify_keys)
      end
    end

    private

    attr_reader :namespace, :params

    def user_iterable_params(user)
      {
        first_name: user.first_name,
        last_name: user.last_name,
        work_email: user.email,
        namespace_id: namespace.id,
        product_interaction: params['product_interaction'],
        opt_in: user.onboarding_status_email_opt_in,
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language)
      }
    end
  end
end
