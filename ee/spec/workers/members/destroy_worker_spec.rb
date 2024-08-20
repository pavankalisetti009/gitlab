# frozen_string_literal: true

require "spec_helper"

RSpec.describe Members::DestroyWorker, feature_category: :user_management do
  describe '#perform' do
    let_it_be(:group) { create(:group) }
    let_it_be(:member) { create(:group_member, group: group) }
    let_it_be(:user) { create(:user) }

    before_all do
      group.add_owner(user)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [member.id, user.id] }

      it 'calls the destroy service' do
        expect_next_instances_of(::Members::DestroyService, worker_exec_times) do |service|
          expect(service).to receive(:execute).with(member, skip_subresources: false)
        end

        perform_idempotent_work
      end

      context 'when skipping subresources' do
        let(:job_args) { [member.id, user.id, true] }

        it 'calls the destroy service with skip_subresources' do
          expect_next_instances_of(::Members::DestroyService, worker_exec_times) do |service|
            expect(service).to receive(:execute).with(member, skip_subresources: true)
          end

          perform_idempotent_work
        end
      end

      shared_examples 'does not call the destroy service' do
        it do
          expect(::Members::DestroyService).not_to receive(:new)

          perform_idempotent_work
        end
      end

      context 'with no user' do
        let(:user) { build(:user) }

        it_behaves_like 'does not call the destroy service'
      end

      context 'with no member' do
        let(:member) { build(:group_member) }

        it_behaves_like 'does not call the destroy service'
      end
    end
  end
end
