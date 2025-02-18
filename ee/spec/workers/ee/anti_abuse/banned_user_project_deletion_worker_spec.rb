# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::BannedUserProjectDeletionWorker, :saas, feature_category: :instance_resiliency do
  let(:worker) { described_class.new }
  let(:admin_bot) { Users::Internal.admin_bot }
  let_it_be_with_reload(:user) { create(:user, :banned) }
  let_it_be_with_reload(:project) { create(:project, creator: user, owners: user) }

  # The factory adds two owners so we need to make sure they are all banned
  before_all do
    project.owners.each { |o| o.ban! if o.active? }
  end

  describe '#perform' do
    subject(:perform) { worker.perform(project.id) }

    shared_examples 'does not destroy the project' do
      specify do
        expect(Projects::DestroyService).not_to receive(:new)

        perform
      end
    end

    shared_examples 'logs the event' do |reason|
      specify do
        expect(Gitlab::AppLogger).to receive(:info).with(
          class: described_class.name,
          message: 'aborted banned user project auto-deletion',
          reason: reason,
          project_id: project.id,
          full_path: project.full_path,
          banned_user_id: project.creator_id
        )

        perform
      end
    end

    context 'when the project is not active', time_travel_to: (described_class::ACTIVITY_THRESHOLD + 1).days.from_now do
      it 'calls Projects::DestroyService' do
        expect_next_instance_of(Projects::DestroyService, project, admin_bot) do |service|
          expect(service).to receive(:async_execute)
        end

        perform
      end

      context 'when the root namespace is paid' do
        let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
        let_it_be_with_reload(:project) { create(:project, group: group, creator: user, owners: user) }

        it_behaves_like 'does not destroy the project'
        it_behaves_like 'logs the event', 'project is paid'
      end

      context 'when the root namespace has purchased compute minutes' do
        before do
          project.namespace.update!(extra_shared_runners_minutes_limit: 100)
          project.namespace.clear_memoization(:ci_minutes_usage)
        end

        it_behaves_like 'does not destroy the project'
        it_behaves_like 'logs the event', 'project is paid'
      end
    end
  end
end
