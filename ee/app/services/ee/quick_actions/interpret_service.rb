# frozen_string_literal: true

module EE
  module QuickActions
    module InterpretService
      extend ActiveSupport::Concern
      # We use "prepended" here instead of including Gitlab::QuickActions::Dsl,
      # as doing so would clear any existing command definitions.
      prepended do
        # rubocop: disable Cop/InjectEnterpriseEditionModule
        include EE::Gitlab::QuickActions::EpicActions
        include EE::Gitlab::QuickActions::IssueActions
        include EE::Gitlab::QuickActions::IssueAndMergeRequestActions
        include EE::Gitlab::QuickActions::MergeRequestActions
        include EE::Gitlab::QuickActions::RelateActions
        include EE::Gitlab::QuickActions::WorkItemActions
        include EE::Gitlab::QuickActions::AmazonQActions
        # rubocop: enable Cop/InjectEnterpriseEditionModule
      end

      def execute(content, quick_action_target, only: nil)
        result = super

        check_quick_actions_availability(result.last)
        result
      end

      private

      def check_quick_actions_availability(commands)
        return if quick_actions_check_not_needed?(commands)
        return if params[:scope_validator].permit_quick_actions?

        message = 'Quick actions cannot be used with AI workflows.'
        raise ::QuickActions::InterpretService::QuickActionsNotAllowedError, message
      end

      def quick_actions_check_not_needed?(commands)
        commands.blank? || params[:scope_validator].blank?
      end
    end
  end
end
