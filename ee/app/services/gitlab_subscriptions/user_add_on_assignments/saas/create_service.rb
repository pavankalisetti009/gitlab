# frozen_string_literal: true

module GitlabSubscriptions
  module UserAddOnAssignments
    module Saas
      class CreateService < ::GitlabSubscriptions::UserAddOnAssignments::BaseCreateService
        include Gitlab::Utils::StrongMemoize

        def execute
          super.tap do |response|
            create_iterable_trigger if should_trigger_duo_pro_iterable? response
          end
        end

        private

        attr_reader :add_on_purchase, :user

        def eligible_for_gitlab_duo_pro_seat?
          namespace.eligible_for_gitlab_duo_pro_seat?(user)
        end
        strong_memoize_attr :eligible_for_gitlab_duo_pro_seat?

        def namespace
          @namespace ||= add_on_purchase.namespace
        end

        def base_log_params
          super.merge(namespace: add_on_purchase.namespace.full_path)
        end

        def should_trigger_duo_pro_iterable?(response)
          response.success? && duo_pro_or_enterprise? && !user_already_assigned?
        end

        def create_iterable_trigger
          ::Onboarding::CreateIterableTriggerWorker.perform_async(iterable_params)
        end

        def iterable_params
          {
            first_name: user.first_name,
            last_name: user.last_name,
            work_email: user.email,
            namespace_id: namespace.id,
            product_interaction: "duo_pro_add_on_seat_assigned",
            opt_in: user.onboarding_status_email_opt_in,
            preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language)
          }
        end
      end
    end
  end
end
