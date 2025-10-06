# frozen_string_literal: true

module EE
  module API
    module Entities
      class ApprovalSettings < Grape::Entity
        expose :approvers, using: EE::API::Entities::Approver do |project|
          if ::Feature.enabled?(:deprecate_approver_and_approver_group, project)
            []
          else
            # delegate to project presenter
            project.approvers
          end
        end
        expose :approver_groups, using: EE::API::Entities::ApproverGroup do |project|
          if ::Feature.enabled?(:deprecate_approver_and_approver_group, project)
            []
          else
            # delegate to project presenter
            project.approver_groups
          end
        end
        expose :approvals_before_merge

        expose :reset_approvals_on_push
        expose(:selective_code_owner_removals) { |project| project.project_setting.selective_code_owner_removals }

        expose :disable_overriding_approvers_per_merge_request?,
          as: :disable_overriding_approvers_per_merge_request

        expose :merge_requests_author_approval?,
          as: :merge_requests_author_approval

        expose :merge_requests_disable_committers_approval?,
          as: :merge_requests_disable_committers_approval

        expose :require_password_to_approve?,
          as: :require_password_to_approve

        expose :require_reauthentication_to_approve?,
          as: :require_reauthentication_to_approve
      end
    end
  end
end
