# frozen_string_literal: true

class AdjournedGroupDeletionWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :always

  include CronjobQueue

  INTERVAL = 20.seconds.to_i

  feature_category :groups_and_projects

  def perform
    deletion_cutoff = Gitlab::CurrentSettings.deletion_adjourned_period.days.ago.to_date

    Group.with_route.aimed_for_deletion(deletion_cutoff)
      .with_deletion_schedule
      .find_each(batch_size: 100) # rubocop: disable CodeReuse/ActiveRecord
      .with_index do |group, index|
      deletion_schedule = group.deletion_schedule
      delay = index * INTERVAL

      user = deletion_schedule.deleting_user

      with_context(namespace: group, user: user) do
        admin_mode = Gitlab::CurrentSettings.admin_mode && user.admin? # rubocop:disable Cop/UserAdmin -- policy checks are enforced further down the stack
        GroupDestroyWorker.perform_in(delay, group.id, deletion_schedule.user_id, admin_mode: admin_mode)
      end
    end
  end
end
