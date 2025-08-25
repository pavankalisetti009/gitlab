# frozen_string_literal: true

module ComplianceManagement
  class UpdateDefaultFrameworkWorker
    include ApplicationWorker

    idempotent!
    data_consistency :always
    urgency :low
    feature_category :compliance_management

    def perform(_user_id, project_id, compliance_framework_id)
      project = Project.find(project_id)
      admin_bot = admin_bot_for_organization_id(project.organization_id)

      Gitlab::Auth::CurrentUserMode.bypass_session!(admin_bot.id) do
        ::ComplianceManagement::Frameworks::UpdateProjectService
          .new(project, admin_bot, [::ComplianceManagement::Framework.find_by_id(compliance_framework_id)])
          .execute
      end
    rescue ActiveRecord::RecordNotFound => e
      Gitlab::ErrorTracking.log_exception(e)
    end

    private

    def admin_bot_for_organization_id(organization_id)
      @admin_bots ||= {}
      @admin_bots[organization_id] ||= Users::Internal.for_organization(organization_id).admin_bot
    end
  end
end
