# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsFinder do
  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be(:ultimate_project) { create_project(:ultimate_plan) }
    let_it_be(:ultimate_project2) { create_project(:ultimate_plan) }
    let_it_be(:premium_project) { create_project(:premium_plan) }
    let_it_be(:no_plan_project) { create_project(nil) }

    let(:project_ids_relation) { nil }
    let(:finder) { described_class.new(current_user: user, params: params, project_ids_relation: project_ids_relation) }

    subject { finder.execute }

    describe 'filter by plans' do
      let(:params) { { plans: plans } }

      context 'with ultimate plan' do
        let(:plans) { ['ultimate'] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2) }
      end

      context 'with multiple plans' do
        let(:plans) { %w[ultimate premium] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project) }
      end

      context 'with other plans' do
        let(:plans) { ['bronze'] }

        it { is_expected.to be_empty }
      end

      context 'without plans' do
        let(:plans) { nil }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end

      context 'with empty plans' do
        let(:plans) { [] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end
    end

    context 'filter by aimed for deletion' do
      let_it_be(:params) { { aimed_for_deletion: true } }
      let_it_be(:aimed_for_deletion_project) { create(:project, :public, marked_for_deletion_at: 2.days.ago, pending_delete: false) }
      let_it_be(:pending_deletion_project) { create(:project, :public, marked_for_deletion_at: 1.month.ago, pending_delete: true) }

      it { is_expected.to contain_exactly(aimed_for_deletion_project) }
    end

    context 'filter by not aimed for deletion' do
      let_it_be(:params) { { not_aimed_for_deletion: true } }
      let_it_be(:aimed_for_deletion_project) { create(:project, :public, marked_for_deletion_at: 2.days.ago, pending_delete: false) }
      let_it_be(:pending_deletion_project) { create(:project, :public, marked_for_deletion_at: 1.month.ago, pending_delete: true) }

      it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
    end

    context 'filter by SAML SSO session' do
      let(:params) { { filter_expired_saml_session_projects: true } }
      let(:finder) { described_class.new(current_user: current_user, params: params) }

      let_it_be(:current_user) { user }

      let_it_be(:root_group1) do
        create(:group, saml_provider: create(:saml_provider), developers: current_user) do |group|
          create_saml_identity(group, current_user)
        end
      end

      let_it_be(:root_group2) do
        create(:group, saml_provider: create(:saml_provider))
      end

      let_it_be(:private_root_group) do
        create(:group, :private, saml_provider: create(:saml_provider), developers: current_user) do |group|
          create_saml_identity(group, current_user)
        end
      end

      let_it_be(:project1) { create(:project, :public, group: root_group1) }
      let_it_be(:project2) { create(:project, :public, group: root_group2) }
      let_it_be(:private_project) { create(:project, :private, group: private_root_group) }
      let_it_be(:all_projects) { [project1, project2, private_project] }

      subject(:projects) { finder.execute.id_in(all_projects).to_a }

      context 'when the current user is nil' do
        let_it_be(:current_user) { nil }

        it 'includes public SAML projects' do
          expect(projects).to contain_exactly(project1, project2)
        end
      end

      shared_examples 'includes all SAML projects' do
        specify do
          expect(projects).to match_array(all_projects)
        end
      end

      context 'when the current user is an admin', :enable_admin_mode do
        let_it_be(:current_user) { create(:admin) }

        it_behaves_like 'includes all SAML projects'
      end

      context 'when the current user has no active SAML sessions' do
        it 'filters out the SAML member projects' do
          expect(projects).to contain_exactly(project2)
        end
      end

      context 'when filter_expired_saml_session_projects param is false' do
        let(:params) { { filter_expired_saml_session_projects: false } }

        it_behaves_like 'includes all SAML projects'
      end

      context 'when the current user has active SAML sessions' do
        before do
          active_saml_sessions = { root_group1.saml_provider.id => Time.current,
                                   private_root_group.saml_provider.id => Time.current }
          allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
        end

        it_behaves_like 'includes all SAML projects'
      end
    end

    context 'filter by hidden' do
      let_it_be(:hidden_project) { create(:project, :public, :hidden) }

      context 'when include hidden is true' do
        let_it_be(:params) { { include_hidden: true } }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project, hidden_project) }
      end

      context 'when include hidden is false' do
        let_it_be(:params) { { include_hidden: false } }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end
    end

    context 'filter by feature available' do
      let_it_be(:private_premium_project) { create_project(:premium_plan, :private) }

      before do
        private_premium_project.add_owner(user)
      end

      context 'when feature_available filter is used' do
        # `product_analytics` is a feature available in Ultimate tier only
        let_it_be(:params) { { feature_available: 'product_analytics' } }

        it do
          is_expected.to contain_exactly(
            ultimate_project,
            ultimate_project2,
            premium_project,
            no_plan_project
          )
        end
      end

      context 'when feature_available filter is not used' do
        let_it_be(:params) { {} }

        it do
          is_expected.to contain_exactly(
            ultimate_project,
            ultimate_project2,
            premium_project,
            no_plan_project,
            private_premium_project
          )
        end
      end
    end

    private

    def create_saml_identity(group, current_user)
      create(:group_saml_identity, saml_provider: group.saml_provider, user: current_user)
    end

    def create_project(plan, visibility = :public)
      create(:project, visibility, namespace: create(:group_with_plan, plan: plan))
    end
  end
end
