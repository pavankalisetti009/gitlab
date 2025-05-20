# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Status, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project) }
  let_it_be_with_reload(:unsupported_work_item) { create(:work_item, :ticket, project: project) }

  let(:target_status) { build(:work_item_system_defined_status, :in_progress) }
  let(:default_open_status) { item.work_item_type.status_lifecycle_for(group.id).default_open_status }

  let(:current_user) { reporter }
  let(:params) { {} }
  let(:item) { work_item }

  let(:callback) { described_class.new(issuable: item, current_user: current_user, params: params) }

  before_all do
    project.add_reporter(reporter)
  end

  def work_item_status
    item.reload.current_status&.status
  end

  shared_examples 'applies target status' do
    it { expect { after_save_callback }.to change { work_item_status }.to(target_status) }
  end

  shared_examples 'preserves work item status' do
    it 'does not change work item status value' do
      expect { after_save_callback }
        .to not_change { work_item_status }
        .and not_change { item.updated_at }
    end

    it_behaves_like 'does not create the system note'
  end

  shared_examples 'creates the system note' do
    it 'creates system note' do
      expect { after_save_callback }.to change { item.notes.count }.by(1)

      note = item.notes.first
      expect(note.note).to eq(format("set status to **%{status_name}**", status_name: target_status.name))
      expect(note.system_note_metadata.action).to eq('work_item_status')
    end
  end

  shared_examples 'does not create the system note' do
    it { expect { after_save_callback }.to not_change { item.notes.count } }
  end

  shared_examples 'raises error' do
    it { expect { after_save_callback }.to raise_error(ActiveRecord::RecordInvalid, error_message) }
  end

  shared_examples 'applies default status with system note' do
    let(:target_status) { default_open_status }

    it_behaves_like 'applies target status'
    it_behaves_like 'creates the system note'
  end

  shared_examples 'applies default status without system note' do
    let(:target_status) { default_open_status }

    it_behaves_like 'applies target status'
    it_behaves_like 'does not create the system note'
  end

  shared_examples 'applies target status with system note' do
    it_behaves_like 'applies target status'
    it_behaves_like 'creates the system note'
  end

  shared_examples 'preserves status when work_item_status_transitions flag is disabled' do
    before do
      stub_feature_flags(work_item_status_transitions: false)
    end

    it_behaves_like 'preserves work item status'
  end

  shared_examples 'preserves currently set status' do
    let_it_be(:current_status) { create(:work_item_current_status, work_item: work_item, system_defined_status_id: 2) }

    it_behaves_like 'preserves work item status'
  end

  shared_examples 'overwrites currently set status with target status' do
    let_it_be(:current_status) { create(:work_item_current_status, work_item: work_item, system_defined_status_id: 1) }

    it_behaves_like 'applies target status with system note'
  end

  shared_examples 'preserves status when item is not supported' do
    let(:item) { unsupported_work_item }

    it_behaves_like 'preserves work item status'
    it_behaves_like 'preserves status when work_item_status_transitions flag is disabled'
  end

  shared_examples 'unlicensed feature' do
    # Because unlicensed we ignore the given status param and apply the
    # default instead because supported items should have a status.
    # No system note because the feature is not visible to the user (license).
    it_behaves_like 'applies default status without system note'
    it_behaves_like 'preserves status when work_item_status_transitions flag is disabled'
    it_behaves_like 'preserves currently set status'
    it_behaves_like 'preserves status when item is not supported'
  end

  shared_examples 'when feature is unlicensed' do
    context 'without params' do
      it_behaves_like 'unlicensed feature'
    end

    context 'with params' do
      let(:params) { { status: target_status } }

      it_behaves_like 'unlicensed feature'
    end
  end

  # We're only testing paths that make a difference
  # and not paths that behave like already tested ones with different setup.
  # This should keep the test suite more compact while ensuring good coverage.
  describe '#after_save' do
    subject(:after_save_callback) { callback.after_save }

    context "when the feature is not licensed" do
      context "when issuable is work_item" do
        it_behaves_like 'when feature is unlicensed'
      end

      context "when issuable is an issue" do
        let(:item) { Issue.find_by_id(work_item) }

        it_behaves_like 'when feature is unlicensed'
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      context "when passing issue as issuable" do
        let(:item) { Issue.find_by_id(work_item) }

        context "without params" do
          it_behaves_like 'applies default status without system note'
          it_behaves_like 'preserves status when work_item_status_transitions flag is disabled'
          it_behaves_like 'preserves currently set status'
          it_behaves_like 'preserves status when item is not supported'
        end

        context "with params" do
          let(:params) { { status: target_status } }

          it_behaves_like 'applies default status without system note'

          context 'with wrong status param type' do
            let(:params) { { status: 4 } }

            it_behaves_like 'applies default status without system note'
          end
        end
      end

      context 'without params' do
        # Show system note because status feature is visible for licensed namespaces with FF on
        it_behaves_like 'applies default status with system note'
        it_behaves_like 'preserves status when work_item_status_transitions flag is disabled'
        it_behaves_like 'preserves currently set status'
        it_behaves_like 'preserves status when item is not supported'
      end

      context 'with params' do
        let(:params) { { status: target_status } }

        it_behaves_like 'applies target status with system note'
        it_behaves_like 'overwrites currently set status with target status'

        context 'with invalid status param' do
          let(:params) { { status: ::WorkItems::Statuses::SystemDefined::Status.new(id: 99, name: 'Invalid') } }

          let(:error_message) do
            "Validation failed: System defined status not provided or references non-existent system defined status"
          end

          it_behaves_like 'raises error'
        end

        context 'with wrong status param type' do
          let(:params) { { status: 4 } }

          it_behaves_like 'applies default status with system note'
        end

        context 'when item is not supported' do
          let(:item) { unsupported_work_item }

          let(:error_message) do
            "Validation failed: System defined status not allowed for this work item type"
          end

          it_behaves_like 'raises error'

          context 'when work_item_status_transitions feature flag is disabled' do
            before do
              stub_feature_flags(work_item_status_transitions: false)
            end

            it_behaves_like 'raises error'
          end
        end

        context 'when work_item_status_transitions feature flag is disabled' do
          before do
            stub_feature_flags(work_item_status_transitions: false)
          end

          it_behaves_like 'applies target status with system note'
          it_behaves_like 'overwrites currently set status with target status'
        end

        context 'when work_item_status_feature_flag feature flag is disabled' do
          before do
            stub_feature_flags(work_item_status_feature_flag: false)
          end

          it_behaves_like 'applies default status without system note'
          it_behaves_like 'preserves currently set status'
        end

        context 'when status related feature flags are disabled' do
          before do
            stub_feature_flags(work_item_status_transitions: false, work_item_status_feature_flag: false)
          end

          it_behaves_like 'preserves work item status'
          it_behaves_like 'preserves currently set status'
        end
      end
    end
  end
end
