# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Status, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project) }
  let_it_be_with_reload(:unsupported_work_item) { create(:work_item, :ticket, project: project) }

  let_it_be(:error_class) { ::Issuable::Callbacks::Base::Error }

  let(:original_status) { ::WorkItems::Statuses::SystemDefined::Status.find(1) }
  let(:target_status) { ::WorkItems::Statuses::SystemDefined::Status.find(2) }

  let(:current_user) { reporter }
  let(:params) { {} }
  let(:callback) { described_class.new(issuable: work_item, current_user: current_user, params: params) }

  before_all do
    project.add_reporter(reporter)
  end

  def work_item_status
    work_item.reload.current_status&.status
  end

  shared_examples 'work item and status is unchanged' do
    it 'does not change work item status value' do
      expect { subject }
        .to not_change { work_item_status }
        .and not_change { work_item.updated_at }
    end
  end

  shared_examples 'raises a callback error' do
    it { expect { subject }.to raise_error(error_class, message) }
  end

  shared_examples 'when status feature is licensed' do
    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'when status param is present and valid' do
      let(:params) { { status: target_status } }

      it 'updates work item status value' do
        expect { subject }.to change { work_item_status }.to(target_status)
      end

      context 'when work item type does not have lifecycle' do
        let(:callback) do
          described_class.new(issuable: unsupported_work_item, current_user: current_user, params: params)
        end

        it_behaves_like 'raises a callback error' do
          let(:message) { "System defined status not allowed for this work item type" }
        end
      end
    end

    context 'when status param is not present' do
      let(:params) { {} }

      it_behaves_like 'work item and status is unchanged'

      context 'when widget does not exist in type' do
        before do
          allow(callback).to receive(:excluded_in_new_type?).and_return(true)
        end

        it_behaves_like 'work item and status is unchanged'
      end
    end

    context 'when status param is of invalid type' do
      let(:params) { { status: 'In progress' } }

      it_behaves_like 'work item and status is unchanged'
    end

    context 'when status param is is invalid status' do
      let(:params) do
        { status: ::WorkItems::Statuses::SystemDefined::Status.new(id: 99, name: 'Invalid') }
      end

      it_behaves_like 'raises a callback error' do
        let(:message) { "System defined status not provided or references non-existent system defined status" }
      end
    end

    context 'when user cannot admin_work_item' do
      let(:current_user) { user }
      let(:params) { { status: target_status } }

      it_behaves_like 'work item and status is unchanged'
    end
  end

  shared_examples 'when status feature is unlicensed' do
    before do
      stub_licensed_features(work_item_status: false)
    end

    it_behaves_like 'work item and status is unchanged'
  end

  describe '#after_initialize' do
    subject(:after_initialize_callback) { callback.after_initialize }

    it_behaves_like 'when status feature is licensed'
    it_behaves_like 'when status feature is unlicensed'

    context 'when current status exists' do
      let_it_be_with_reload(:current_status) do
        create(:work_item_current_status, work_item: work_item, system_defined_status_id: 1)
      end

      it_behaves_like 'when status feature is licensed'
      it_behaves_like 'when status feature is unlicensed'
    end
  end

  describe '#after_save' do
    subject(:after_save_callback) { callback.after_save }

    let_it_be_with_reload(:current_status) do
      create(:work_item_current_status, work_item: work_item, system_defined_status_id: 2)
    end

    it "does not create system notes when status didn't change" do
      expect { after_save_callback }.to not_change { work_item.notes.count }
    end

    context 'when status was updated' do
      before do
        allow(work_item.current_status).to receive_message_chain(:previous_changes, :include?).and_return(true)
      end

      it 'creates system note' do
        expect { after_save_callback }.to change { work_item.notes.count }.by(1)

        note = work_item.notes.first
        expect(note.note).to eq(format("set status to **%{status_name}**", status_name: target_status.name))
        expect(note.system_note_metadata.action).to eq('work_item_status')
      end
    end
  end
end
