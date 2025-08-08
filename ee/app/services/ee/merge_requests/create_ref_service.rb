# frozen_string_literal: true

module EE
  module MergeRequests
    module CreateRefService
      extend ::Gitlab::Utils::Override

      override :should_store_generated_ref_commits?

      def should_store_generated_ref_commits?
        super || (::Feature.enabled?(:generate_ref_commits, merge_request.target_project) &&
          target_project.can_create_new_ref_commits? && merge_request.merge_train_car.present?)
      end
    end
  end
end
