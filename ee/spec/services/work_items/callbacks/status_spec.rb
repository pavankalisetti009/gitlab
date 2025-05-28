# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Status, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project) }
  let_it_be_with_reload(:unsupported_work_item) { create(:work_item, :ticket, project: project) }

  let(:in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let(:done_status) { build(:work_item_system_defined_status, :done) }
  let(:default_open_status) { build(:work_item_system_defined_status, :to_do) }
  let(:item) { work_item }
  let(:params) { {} }
  let(:status_update_service) { instance_double(WorkItems::Widgets::Statuses::UpdateService) }

  subject(:callback) { described_class.new(issuable: item, current_user: current_user, params: params) }

  before_all do
    project.add_reporter(current_user)
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  def work_item_status
    item.reload.current_status&.status
  end

  shared_examples 'does not call services to create current status record' do
    it 'does not update the status' do
      expect(Issues::ReopenService).not_to receive(:new)
      expect(Issues::CloseService).not_to receive(:new)
      expect(::WorkItems::Widgets::Statuses::UpdateService).not_to receive(:new)

      after_save_callback
    end
  end

  shared_examples 'handle status for open state' do
    context "when work items state is open" do
      it "calls the status update service with a status with open state" do
        expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
          .with(item, current_user, status)
          .and_return(status_update_service)
        expect(status_update_service).to receive(:execute)
        expect(status.state).to eq(:open)

        after_save_callback
      end
    end

    context "when work items state is closed" do
      before do
        item.close(current_user)
      end

      it "calls the reopen with a status with open state" do
        expect(Issues::ReopenService).to receive_message_chain(:new, :execute).with(item, status: status)
        expect(status.state).to eq(:open)

        after_save_callback
      end
    end
  end

  shared_examples 'handle status for closed state' do
    context "when work items state is closed" do
      before do
        item.close(current_user)
      end

      it "calls the status update service with a status with closed state" do
        expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
          .with(item, current_user, status)
          .and_return(status_update_service)
        expect(status_update_service).to receive(:execute)
        expect(status.state).to eq(:closed)

        after_save_callback
      end
    end

    context "when work items state is open" do
      it "calls the close with an status with closed state" do
        expect(Issues::CloseService).to receive_message_chain(:new, :execute).with(item, status: status)
        expect(status.state).to eq(:closed)

        after_save_callback
      end
    end
  end

  describe '.execute_without_params?' do
    it 'returns true' do
      expect(described_class.execute_without_params?).to be true
    end
  end

  describe '#after_save' do
    subject(:after_save_callback) { callback.after_save }

    context 'when user does not have permission' do
      before do
        allow(callback).to receive(:has_permission?).and_return(false)
      end

      it_behaves_like 'does not call services to create current status record'
    end

    context 'when work item is excluded in new type' do
      before do
        allow(callback).to receive(:excluded_in_new_type?).and_return(true)
      end

      it_behaves_like 'does not call services to create current status record'
    end

    context "when current stautus exist and params are empty" do
      let!(:current_status) { create(:work_item_current_status, work_item: item) }

      it_behaves_like 'does not call services to create current status record'
    end

    context "for system defined lifecycle" do
      context "when params are empty" do
        it_behaves_like 'handle status for open state' do
          let(:status) { default_open_status }
        end
      end

      context "when params are present" do
        context "when status category has open state" do
          let(:params) { { status: in_progress_status } }

          it_behaves_like 'handle status for open state' do
            let(:status) { in_progress_status }
          end
        end

        context "when status category has closed state" do
          let(:params) { { status: done_status } }

          it_behaves_like 'handle status for closed state' do
            let(:status) { done_status }
          end
        end
      end
    end

    context "for custom lifecycle" do
      let!(:status_lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
          create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item.work_item_type)
        end
      end

      let(:open_status) { status_lifecycle.default_open_status }
      let(:closed_status) { status_lifecycle.default_closed_status }

      context "when params are empty" do
        it_behaves_like 'handle status for open state' do
          let(:status) { open_status }
        end
      end

      context "when params are present" do
        context "when status category has open state" do
          let(:params) { { status: open_status } }

          it_behaves_like 'handle status for open state' do
            let(:status) { open_status }
          end
        end

        context "when status category has closed state" do
          let(:params) { { status: closed_status } }

          it_behaves_like 'handle status for closed state' do
            let(:status) { closed_status }
          end
        end
      end
    end
  end
end
