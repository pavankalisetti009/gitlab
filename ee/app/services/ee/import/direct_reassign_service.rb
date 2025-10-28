# frozen_string_literal: true

module EE
  module Import
    module DirectReassignService
      extend ActiveSupport::Concern

      EE_MODEL_LIST = {
        "ApprovalProjectRulesUser" => ["user_id"],
        "BoardAssignee" => ["assignee_id"],
        "ProtectedBranch::UnprotectAccessLevel" => ["user_id"],
        "ProtectedEnvironments::DeployAccessLevel" => ["user_id"],
        "ResourceIterationEvent" => ["user_id"]
      }.freeze

      class_methods do
        extend ::Gitlab::Utils::Override

        override :model_list
        def model_list
          super.merge(EE_MODEL_LIST)
        end
      end
    end
  end
end
