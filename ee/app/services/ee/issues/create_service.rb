# frozen_string_literal: true

module EE
  module Issues
    module CreateService
      extend ::Gitlab::Utils::Override

      include ::Observability::MetricsIssuesHelper

      override :create
      def create(issuable, skip_system_notes: false)
        process_iteration_id
        # rubocop:disable Gitlab/ModuleWithInstanceVariables -- need to define access to this variable in
        #   process_observability_links, and stop Rails from reading `observability_links` as a model attribute.
        @observability_links = params.delete(:observability_links)
        # rubocop:enable Gitlab/ModuleWithInstanceVariables

        super
      end

      override :filter_params
      def filter_params(issue)
        filter_epic(issue)

        super
      end

      override :transaction_create
      def transaction_create(issue)
        return super unless issue.work_item_type.requirement?

        requirement = issue.build_requirement(project: issue.project)
        requirement.requirement_issue = issue

        issue.requirement_sync_error! unless requirement.valid?

        super
      end

      private

      override :after_create
      def after_create(issue)
        super

        # rubocop:disable Gitlab/ModuleWithInstanceVariables -- see declaration at top of file
        if can?(current_user, :read_observability, issue.project)
          process_observability_links(issue, @observability_links)
        end
        # rubocop:enable Gitlab/ModuleWithInstanceVariables

        return unless issue.previous_changes.include?(:milestone_id) && issue.epic_issue

        ::Epics::UpdateDatesService.new([issue.epic_issue.epic]).execute
      end
    end
  end
end
