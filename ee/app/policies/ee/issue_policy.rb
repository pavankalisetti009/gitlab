# frozen_string_literal: true

module EE
  module IssuePolicy
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    override :epics_license_available?
    def epics_license_available?
      subject_container.licensed_feature_available?(:epics) || super
    end

    override :project_work_item_epics_available?
    def project_work_item_epics_available?
      (subject_container.project_epics_enabled? && epics_license_available?) || super
    end

    prepended do
      rule { can_be_promoted_to_epic }.policy do
        enable :promote_to_epic
      end

      # summarize comments is enabled at namespace(project or group) level, however if issue is confidential
      # and user(e.g. guest cannot read issue) we do not allow summarize comments
      rule { ~can?(:read_issue) }.policy do
        prevent :summarize_comments
      end

      # This rule is already defined in FOSS IssuePolicy, but EE::IssuePolicy may be adding EE specific abilities
      # that would be captured here, e.g. `summarize_comments`, `promote_to_epic`, etc
      rule { ~work_item_type_available }.policy do
        prevent(*::IssuePolicy.ability_map.map.keys)
      end
    end
  end
end
