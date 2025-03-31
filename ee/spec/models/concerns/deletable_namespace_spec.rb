# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeletableNamespace, feature_category: :groups_and_projects do
  describe Group, pending: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/527085' do
    let_it_be_with_reload(:group) { create(:group) }

    describe '#self_deletion_scheduled_deletion_created_on' do
      subject { group.self_deletion_scheduled_deletion_created_on }

      context 'when the group is not marked for delayed deletion' do
        it { is_expected.to be_falsey }
      end

      context 'when the group is marked for delayed deletion', :freeze_time do
        before do
          create(:group_deletion_schedule, group: group, marked_for_deletion_on: Date.yesterday)
        end

        it { is_expected.to eq(Date.yesterday) }
      end
    end

    describe '#scheduled_for_deletion_in_hierarchy_chain' do
      context 'when the group has been marked for deletion' do
        before do
          create(:group_deletion_schedule, group: group, marked_for_deletion_on: 1.day.ago)
        end

        it 'returns the group' do
          expect(group.scheduled_for_deletion_in_hierarchy_chain).to eq([group])
        end
      end

      context 'when the parent group has been marked for deletion' do
        let(:parent_group) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago) }
        let(:group) { create(:group, parent: parent_group) }

        it 'returns the parent group' do
          expect(group.scheduled_for_deletion_in_hierarchy_chain).to eq([parent_group])
        end
      end

      context 'when parent group has not been marked for deletion' do
        let(:parent_group) { create(:group) }
        let(:group) { create(:group, parent: parent_group) }

        it 'returns nil' do
          expect(group.scheduled_for_deletion_in_hierarchy_chain).to eq([])
        end
      end

      describe 'ordering of parents marked for deletion' do
        let(:group_a) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago) }
        let(:subgroup_a) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago, parent: group_a) }
        let(:group) { create(:group, parent: subgroup_a) }

        it 'returns the ancestors marked for deletion, ordered from closest to farthest' do
          expect(group.scheduled_for_deletion_in_hierarchy_chain).to eq([subgroup_a, group_a])
        end
      end
    end
  end

  describe Project, pending: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/527085' do
    let_it_be(:project) { create(:project) }

    describe '#self_deletion_scheduled_deletion_created_on' do
      subject { project.self_deletion_scheduled_deletion_created_on }

      context 'when the project is not marked for delayed deletion' do
        it { is_expected.to be_falsey }
      end

      context 'when the project is marked for delayed deletion', :freeze_time do
        before do
          project.update!(marked_for_deletion_on: Date.yesterday)
        end

        it { is_expected.to eq(Date.yesterday) }
      end
    end

    describe '#delayed_deletion_available?' do
      shared_examples 'delayed deletion available check' do |feature_available|
        context "when License.feature_available? is #{feature_available}" do
          before do
            stub_licensed_features(adjourned_deletion_for_projects_and_groups: feature_available)
          end

          it "returns #{feature_available}" do
            expect(project.delayed_deletion_available?).to be(feature_available)
          end
        end
      end

      it_behaves_like 'delayed deletion available check', true
      it_behaves_like 'delayed deletion available check', false
    end

    describe '#delayed_deletion_configured?' do
      subject { project.delayed_deletion_configured? }

      context 'when project is personal' do
        it { is_expected.to be_falsy }
      end

      context 'when project is not personal' do
        let_it_be(:project) { create(:project, :in_group) }

        it { is_expected.to be_truthy }
      end
    end

    describe '#scheduled_for_deletion_in_hierarchy_chain' do
      context 'when the parent group has been marked for deletion' do
        let_it_be(:parent_group) do
          create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago)
        end

        let_it_be(:project) { create(:project, namespace: parent_group) }

        it 'returns the parent group' do
          expect(project.scheduled_for_deletion_in_hierarchy_chain).to eq([parent_group])
        end
      end

      context 'when parent group has not been marked for deletion' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:project) { create(:project, namespace: parent_group) }

        it 'returns nil' do
          expect(project.scheduled_for_deletion_in_hierarchy_chain).to eq([])
        end
      end

      describe 'ordering of parents marked for deletion' do
        let_it_be(:group_a) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago) }
        let_it_be(:subgroup_a) do
          create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago, parent: group_a)
        end

        let_it_be(:project) { create(:project, namespace: subgroup_a) }

        it 'returns the ancestors marked for deletion, ordered from closest to farthest' do
          expect(project.scheduled_for_deletion_in_hierarchy_chain).to eq([subgroup_a, group_a])
        end
      end
    end
  end
end
