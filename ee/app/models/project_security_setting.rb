# frozen_string_literal: true
#
class ProjectSecuritySetting < ApplicationRecord
  self.primary_key = :project_id

  belongs_to :project, inverse_of: :security_setting

  scope :for_projects, ->(project_ids) { where(project_id: project_ids) }

  def set_continuous_vulnerability_scans!(enabled:)
    enabled if update!(continuous_vulnerability_scans_enabled: enabled)
  end

  def set_container_scanning_for_registry!(enabled:)
    enabled if update!(container_scanning_for_registry_enabled: enabled)
  end

  def set_pre_receive_secret_detection!(enabled:)
    enabled if update!(pre_receive_secret_detection_enabled: enabled)
  end
end
