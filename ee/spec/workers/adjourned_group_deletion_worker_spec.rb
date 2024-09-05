# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AdjournedGroupDeletionWorker, feature_category: :groups_and_projects do
  describe "#perform" do
    subject(:worker) { described_class.new }

    let_it_be(:user) { create(:user) }
    let_it_be(:group_not_marked_for_deletion) { create(:group) }

    let_it_be(:group_marked_for_deletion) do
      create(
        :group_with_deletion_schedule,
        marked_for_deletion_on: 14.days.ago,
        deleting_user: user
      )
    end

    let_it_be(:group_marked_for_deletion_for_later) do
      create(
        :group_with_deletion_schedule,
        marked_for_deletion_on: 2.days.ago,
        deleting_user: user
      )
    end

    before do
      stub_application_setting(deletion_adjourned_period: 14)
    end

    it 'only schedules to delete groups marked for deletion on or before the specified `deletion_adjourned_period`' do
      expect(GroupDestroyWorker).to receive(:perform_in).with(0, group_marked_for_deletion.id, user.id, admin_mode: false)

      worker.perform
    end

    it 'does not schedule to delete a group not marked for deletion' do
      expect(GroupDestroyWorker).not_to receive(:perform_in).with(0, group_not_marked_for_deletion.id, user.id, admin_mode: false)

      worker.perform
    end

    it 'does not schedule to delete a group that is marked for deletion after the specified `deletion_adjourned_period`' do
      expect(GroupDestroyWorker).not_to receive(:perform_in).with(0, group_marked_for_deletion_for_later.id, user.id, admin_mode: false)

      worker.perform
    end

    it 'schedules groups 20 seconds apart' do
      group_marked_for_deletion_2 = create(
        :group_with_deletion_schedule,
        marked_for_deletion_on: 14.days.ago,
        deleting_user: user
      )

      expect(GroupDestroyWorker).to receive(:perform_in).with(0, group_marked_for_deletion.id, user.id, admin_mode: false)
      expect(GroupDestroyWorker).to receive(:perform_in).with(20, group_marked_for_deletion_2.id, user.id, admin_mode: false)

      worker.perform
    end

    context 'when admin_mode setting is enabled but group was not deleted by admin' do
      before do
        stub_application_setting(admin_mode: true)
      end

      it 'does not pass admin_mode flag to GroupDestroyWorker' do
        expect(GroupDestroyWorker).to receive(:perform_in).with(0, group_marked_for_deletion.id, user.id, admin_mode: false)

        worker.perform
      end
    end
  end

  context 'when group was deleted by admin' do
    let_it_be(:admin) { create(:user, :admin) }

    let_it_be(:group_marked_for_deletion) do
      create(
        :group_with_deletion_schedule,
        marked_for_deletion_on: 14.days.ago,
        deleting_user: admin
      )
    end

    describe '#perform' do
      subject(:perform) { described_class.new.perform }

      context 'when admin_mode setting is enabled' do
        before do
          stub_application_setting(admin_mode: true)
        end

        it 'passes admin_mode option to GroupDestroyWorker' do
          expect(GroupDestroyWorker).to receive(:perform_in).with(0, group_marked_for_deletion.id, admin.id, admin_mode: true)

          perform
        end
      end

      context 'when admin_mode setting is disabled' do
        before do
          stub_application_setting(admin_mode: false)
        end

        it 'does not pass admin_mode option to GroupDestroyWorker' do
          expect(GroupDestroyWorker).to receive(:perform_in).with(0, group_marked_for_deletion.id, admin.id, admin_mode: false)

          perform
        end
      end
    end
  end
end
