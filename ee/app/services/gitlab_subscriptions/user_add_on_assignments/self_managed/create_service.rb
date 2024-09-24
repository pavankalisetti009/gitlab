# frozen_string_literal: true

module GitlabSubscriptions
  module UserAddOnAssignments
    module SelfManaged
      class CreateService < ::GitlabSubscriptions::UserAddOnAssignments::BaseCreateService
        include Gitlab::Utils::StrongMemoize

        def execute
          super.tap do |response|
            send_duo_seat_assignment_email if should_send_duo_seat_assignment_email? response
          end
        end

        private

        attr_reader :add_on_purchase, :user

        def eligible_for_gitlab_duo_pro_seat?
          user.eligible_for_self_managed_gitlab_duo_pro?
        end
        strong_memoize_attr :eligible_for_gitlab_duo_pro_seat?

        def send_duo_seat_assignment_email
          DuoSeatAssignmentMailer.duo_pro_email(user).deliver_later
        end

        def should_send_duo_seat_assignment_email?(response)
          Feature.enabled?(:duo_seat_assignment_email_for_sm, :instance) &&
            !user_already_assigned? &&
            response.success? &&
            add_on_purchase.add_on.code_suggestions? # checking if it is a duo_pro add_on
        end
      end
    end
  end
end
