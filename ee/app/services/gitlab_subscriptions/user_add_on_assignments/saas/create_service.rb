# frozen_string_literal: true

module GitlabSubscriptions
  module UserAddOnAssignments
    module Saas
      class CreateService < ::GitlabSubscriptions::UserAddOnAssignments::Saas::CreateWithoutNotificationService
        def execute
          super.tap do |response|
            create_iterable_trigger if should_trigger_duo_iterable? response
          end
        end

        private

        def should_trigger_duo_iterable?(response)
          response.success? && duo_pro_or_enterprise? && !user_already_assigned?
        end

        def duo_pro_or_enterprise?
          add_on_purchase.add_on.code_suggestions? || add_on_purchase.add_on.duo_enterprise?
        end

        def create_iterable_trigger
          ::Onboarding::CreateIterableTriggerWorker.perform_async(iterable_params)
        end

        def iterable_params
          ::Onboarding.add_on_seat_assignment_iterable_params(
            user,
            ::GitlabSubscriptions::AddOns::VARIANTS[add_on_purchase.add_on_name.to_sym][:product_interaction],
            namespace
          )
        end
      end
    end
  end
end
