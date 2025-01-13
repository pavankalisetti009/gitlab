# frozen_string_literal: true

class GroupDeletionSchedule < ApplicationRecord
  belongs_to :group
  belongs_to :deleting_user, foreign_key: 'user_id', class_name: 'User'

  validates :marked_for_deletion_on, presence: true
  validate :excludes_security_policy_projects, if: :group, on: :create

  private

  def excludes_security_policy_projects
    return unless ::Feature.enabled?(:reject_security_policy_project_deletion_groups, group)
    return unless group.licensed_feature_available?(:security_orchestration_policies)
    return unless ::Security::OrchestrationPolicyConfiguration.for_management_project(group.all_project_ids).exists?

    errors.add(:base, _('Group cannot be deleted because one of its projects is linked as Security Policy Project'))
  end
end
