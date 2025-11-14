# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::V2ApprovalRules::ParamsFilteringService, feature_category: :source_code_management do
  let_it_be(:project_member) { create(:user) }
  let_it_be(:outsider) { create(:user) }
  let_it_be(:accessible_group) { create(:group, :private) }
  let_it_be(:accessible_subgroup) { create(:group, :private, parent: accessible_group) }
  let_it_be(:inaccessible_group) { create(:group, :private) }
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(merge_request, user, params) }

  describe '#execute' do
    before_all do
      project.add_maintainer(user)
      project.add_reporter(project_member)

      accessible_group.add_developer(user)
    end

    context 'when filtering create params' do
      let(:merge_request) { build(:merge_request, target_project: project, source_project: project) }
      let(:params) do
        {
          title: 'Awesome merge_request',
          description: 'please fix',
          source_branch: 'feature',
          target_branch: 'master',
          force_remove_source_branch: '1',
          approval_rules_attributes: approval_rules_attributes
        }
      end

      context 'with v2_approval_rules_attributes' do
        let(:params) do
          {
            title: 'Awesome merge_request',
            description: 'please fix',
            source_branch: 'feature',
            target_branch: 'master',
            v2_approval_rules_attributes: [{ name: 'Test Rule', approvals_required: 2 }]
          }
        end

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability)
            .to receive(:allowed?)
                  .with(user, :update_approvers, merge_request)
                  .and_return(can_update_approvers?)
        end

        context 'when user can update approvers' do
          let(:can_update_approvers?) { true }

          before do
            stub_feature_flags(v2_approval_rules: true)
          end

          it 'keeps v2_approval_rules_attributes' do
            expect(service.execute).to include(:v2_approval_rules_attributes)
          end
        end

        context 'when user cannot update approvers' do
          let(:can_update_approvers?) { false }

          it 'removes v2_approval_rules_attributes' do
            expect(service.execute).not_to include(:v2_approval_rules_attributes)
          end
        end
      end
    end
  end
end
