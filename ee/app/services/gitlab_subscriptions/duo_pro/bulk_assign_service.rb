# frozen_string_literal: true

module GitlabSubscriptions
  module DuoPro
    class BulkAssignService < BaseService
      include ::GitlabSubscriptions::SubscriptionHelper
      include Gitlab::Utils::StrongMemoize

      ERROR_NOT_ENOUGH_SEATS = 'NOT_ENOUGH_SEATS'
      ERROR_INVALID_USER_ID_PRESENT = 'INVALID_USER_ID_PRESENT'

      NotEnoughSeatsError = Class.new(StandardError)

      def initialize(add_on_purchase:, user_ids:)
        @add_on_purchase = add_on_purchase
        @user_ids = user_ids.to_set
      end

      def execute
        ineligible_user_ids = user_ids - eligible_user_ids
        return invalid_user_id_present if ineligible_user_ids.any?

        ensure_seat_availability

        upsert_data = eligible_user_ids.map { |user_id| { user_id: user_id } }

        add_on_purchase.with_lock do
          ensure_seat_availability

          add_on_purchase.assigned_users.upsert_all(
            upsert_data,
            unique_by: %i[add_on_purchase_id user_id]
          )
        end

        # Currently we do not support iterables and onboarding for SM-instances
        # Refer to https://gitlab.com/gitlab-org/gitlab/-/issues/461229#note_1965100459
        if gitlab_com_subscription?
          ::Onboarding::CreateIterableTriggersWorker.perform_async(namespace.id, eligible_user_ids)
        end

        Gitlab::AppLogger.info(log_events(type: 'success',
          payload: { users: eligible_user_ids }))
        ServiceResponse.success(payload: { users: User.id_in(eligible_user_ids) })

      rescue NotEnoughSeatsError
        not_enough_seats
      end

      private

      attr_reader :add_on_purchase, :user_ids

      def invalid_user_id_present
        Gitlab::AppLogger.error(log_events(type: 'error',
          payload: { errors: ERROR_INVALID_USER_ID_PRESENT, user_ids: user_ids }))
        ServiceResponse.error(message: ERROR_INVALID_USER_ID_PRESENT)
      end

      def not_enough_seats
        Gitlab::AppLogger.error(log_events(type: 'error', payload: { errors: ERROR_NOT_ENOUGH_SEATS }))
        ServiceResponse.error(message: ERROR_NOT_ENOUGH_SEATS)
      end

      def ensure_seat_availability
        raise NotEnoughSeatsError unless seats_available?
      end

      def seats_available?
        assigned_user_ids = assigned_users.select(:user_id).map(&:user_id)
        available_seats = add_on_purchase.quantity - assigned_user_ids.count

        available_seats >= eligible_users_count_excluding_assigned_users(assigned_user_ids)
      end

      def eligible_users_count_excluding_assigned_users(assigned_user_ids)
        eligible_user_ids.count { |user_id| assigned_user_ids.exclude?(user_id) }
      end

      def assigned_users
        add_on_purchase.assigned_users
      end

      def eligible_user_ids
        gitlab_com_subscription? ? saas_eligible_user_ids : sm_eligible_user_ids
      end
      strong_memoize_attr :eligible_user_ids

      def saas_eligible_user_ids
        namespace.gitlab_duo_pro_eligible_user_ids & user_ids
      end

      # rubocop: disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- Safe because query filters based on passed user_ids
      def sm_eligible_user_ids
        GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(add_on_type: :code_suggestions).execute
          .where(id: user_ids)
          .pluck(:id)
      end
      # rubocop: enable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit

      def namespace
        @namespace ||= add_on_purchase.namespace
      end

      def log_events(type:, payload:)
        {
          add_on_purchase_id: add_on_purchase.id,
          message: 'Duo Pro Bulk User Assignment',
          response_type: type,
          payload: payload
        }
      end
    end
  end
end
