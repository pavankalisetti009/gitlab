# frozen_string_literal: true

module EE
  module Emails # rubocop:disable Gitlab/BoundedContexts -- Existing module
    module Groups
      def group_scheduled_for_deletion(recipient_id, group_id)
        @group = ::Group.find(group_id)
        @user = ::User.find(recipient_id)
        @deletion_due_in_days = ::Gitlab::CurrentSettings.deletion_adjourned_period.days
        @deletion_date = @group.permanent_deletion_date(@group.marked_for_deletion_on)

        email_with_layout(
          to: @user.email,
          subject: subject('Group scheduled for deletion')
        )
      end
    end
  end
end
