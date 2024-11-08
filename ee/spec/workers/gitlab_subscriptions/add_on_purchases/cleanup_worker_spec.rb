# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::CleanupWorker, feature_category: :subscription_management do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it { is_expected.to include_module(CronjobQueue) }
  it { expect(described_class.get_feature_category).to eq(:subscription_management) }

  describe '#perform' do
    let!(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        add_on: add_on,
        expires_on: expires_on.to_date,
        namespace: namespace
      )
    end

    let(:add_on) { create(:gitlab_subscription_add_on) }
    let(:namespace) { create(:group) }
    let(:expires_on) { 1.day.from_now }

    it_behaves_like 'an idempotent worker' do
      subject(:worker) { described_class.new }

      it 'does nothing' do
        expect { worker.perform }.to not_change { add_on_purchase.reload }
      end

      context 'with expired add_on_purchase' do
        let(:expires_on) { (GitlabSubscriptions::AddOnPurchase::CLEANUP_DELAY_PERIOD + 1.day).ago }

        it 'does nothing' do
          expect { worker.perform }.to not_change { add_on_purchase.reload }
        end

        it 'does not log a deletion message' do
          expect(Gitlab::AppLogger).not_to receive(:info)

          worker.perform
        end

        context 'with assigned_users' do
          let(:user_1) { create(:user) }
          let(:user_2) { create(:user) }

          let!(:user_add_on_assignment_1) do
            create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user_1)
          end

          let!(:user_add_on_assignment_2) do
            create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user_2)
          end

          let(:message) do
            'User add-on assignments for GitlabSubscriptions::AddOnPurchase were deleted via scheduled CronJob'
          end

          let(:expected_log) do
            {
              add_on: add_on.name,
              message: message,
              namespace: namespace.path,
              user_add_on_assignments_count: 2
            }
          end

          it 'destroys add-on purchase assigned users' do
            worker.perform

            add_on_purchase.reload
            expect(add_on_purchase.assigned_users).to be_empty
          end

          it 'logs the deletion' do
            expect(Gitlab::AppLogger).to receive(:info).with(expected_log)

            worker.perform
          end

          context 'without namespace' do
            let(:namespace) { nil }
            let(:expected_log) do
              {
                add_on: add_on.name,
                message: message,
                namespace: nil,
                user_add_on_assignments_count: 2
              }
            end

            it 'logs the deletion with blank namespace' do
              expect(Gitlab::AppLogger).to receive(:info).with(expected_log)

              worker.perform
            end
          end
        end
      end
    end
  end
end
