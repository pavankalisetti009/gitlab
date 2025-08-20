# frozen_string_literal: true

module Groups
  module Settings
    class MergeRequestsController < Groups::ApplicationController
      layout 'group_settings'

      before_action :authorize_manage_merge_request_settings!

      feature_category :code_review_workflow

      def update
        return render_404 unless merge_request_settings_available?

        if Groups::UpdateService.new(@group, current_user, group_settings_params).execute
          notice = format(
            _("Group '%{group_name}' was successfully updated."),
            group_name: @group.name
          )
          redirect_to edit_group_path(@group, anchor: 'js-merge-requests-settings'), notice: notice
        else
          @group.reset
          alert = @group.errors.full_messages.to_sentence.presence || format(
            _("Group '%{group_name}' could not be updated."),
            group_name: @group.name
          )
          redirect_to edit_group_path(@group, anchor: 'js-merge-requests-settings'), alert: alert
        end
      end

      private

      def group_settings_params
        params.require(:namespace_setting).permit(
          %i[
            only_allow_merge_if_pipeline_succeeds
            allow_merge_on_skipped_pipeline
            only_allow_merge_if_all_discussions_are_resolved
            allow_merge_without_pipeline
            auto_duo_code_review_enabled
          ]
        )
      end

      def merge_request_settings_available?
        @group.licensed_feature_available?(:group_level_merge_checks_setting) ||
          @group.auto_duo_code_review_settings_available?
      end
    end
  end
end

Groups::Settings::MergeRequestsController.prepend_mod
