# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsFinder, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be(:ultimate_project) { create_project(:ultimate_plan) }
    let_it_be(:ultimate_project2) { create_project(:ultimate_plan) }
    let_it_be(:premium_project) { create_project(:premium_plan) }
    let_it_be(:no_plan_project) { create_project(nil) }

    let(:current_user) { user }
    let(:project_ids_relation) { nil }
    let(:finder) { described_class.new(current_user:, params:, project_ids_relation:) }

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

    it_behaves_like 'projects finder with SAML session filtering' do
      let(:finder) { described_class.new(current_user: current_user, params: params) }
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

    context 'filter by code_embeddings_indexed' do
      let_it_be(:params) { { with_code_embeddings_indexed: true } }

      let_it_be(:namespace) { create(:group) }
      let!(:code_embeddings_enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, namespace: namespace)
      end

      let!(:code_embeddings_repository_1) do
        create(
          :ai_active_context_code_repository,
          project: ultimate_project,
          enabled_namespace: code_embeddings_enabled_namespace
        )
      end

      let!(:code_embeddings_repository_2) do
        create(
          :ai_active_context_code_repository,
          project: ultimate_project2,
          enabled_namespace: code_embeddings_enabled_namespace
        )
      end

      let!(:code_embeddings_repository_3) do
        create(
          :ai_active_context_code_repository,
          project: premium_project,
          enabled_namespace: code_embeddings_enabled_namespace
        )
      end

      let(:project_ids_relation) do
        [ultimate_project.id, ultimate_project2.id, premium_project.id, no_plan_project.id]
      end

      context 'when ai_active_context_connection is inactive' do
        it 'returns no project' do
          is_expected.to be_empty
        end
      end

      context 'when ai_active_context_connection is active' do
        before do
          code_embeddings_enabled_namespace.active_context_connection.reload.update!(active: true)
        end

        context 'when code_embeddings_repository is not ready' do
          it 'returns no project code_embeddings_repository' do
            is_expected.to be_empty
          end
        end

        context 'when code_embeddings_repository are ready' do
          before do
            code_embeddings_repository_1.update!(state: :ready)
            code_embeddings_repository_3.update!(state: :ready)
          end

          it 'returns project with ready code_embeddings_repository' do
            is_expected.to contain_exactly(ultimate_project, premium_project)
          end

          context 'when ff allow_with_code_embeddings_indexed_projects_filter is false' do
            before do
              stub_feature_flags(allow_with_code_embeddings_indexed_projects_filter: false)
            end

            it 'projects are not filtered by with_code_embeddings_indexed' do
              is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project)
            end
          end

          context 'when project_ids_relation is nil' do
            let(:project_ids_relation) { nil }

            it 'projects are not filtered by with_code_embeddings_indexed' do
              is_expected.to be_empty
            end
          end

          context 'when project_ids_relation is an active_record_relation' do
            let(:project_ids_relation) { Project.where(id: [ultimate_project.id]) }

            it 'projects are not filtered by with_code_embeddings_indexed' do
              is_expected.to be_empty
            end
          end
        end
      end
    end

    context 'when filtering by with_duo_eligible' do
      let_it_be(:params) { { with_duo_eligible: true } }

      let_it_be_with_reload(:ns_gold) { create(:group) }
      let_it_be_with_reload(:ns_ultimate) { create(:group) }
      let_it_be_with_reload(:ns_trial) { create(:group) }
      let_it_be_with_reload(:ns_trial_paid) { create(:group) }
      let_it_be_with_reload(:ns_oss) { create(:group) }
      let_it_be_with_reload(:ns_free) { create(:group) }

      let_it_be_with_reload(:p_gold) { create(:project, namespace: ns_gold) }
      let_it_be_with_reload(:p_ultimate) { create(:project, namespace: ns_ultimate) }
      let_it_be_with_reload(:p_trial) { create(:project, namespace: ns_trial) }
      let_it_be_with_reload(:p_trial_paid) { create(:project, namespace: ns_trial_paid) }
      let_it_be_with_reload(:p_oss) { create(:project, namespace: ns_oss) }
      let_it_be_with_reload(:p_free) { create(:project, namespace: ns_free) }

      before do
        [p_gold, p_ultimate, p_trial, p_trial_paid, p_oss, p_free].each do |p|
          p.project_setting.update!(duo_features_enabled: true)
        end

        [ns_gold, ns_ultimate, ns_trial, ns_trial_paid, ns_oss, ns_free].each do |ns|
          ns.namespace_settings.update!(experiment_features_enabled: true)
        end

        gold_plan = create(:gold_plan)
        ultimate_plan = create(:ultimate_plan)
        trial_plan = create(:ultimate_trial_plan)
        trial_paid_plan = create(:ultimate_trial_paid_customer_plan)
        oss_plan = create(:opensource_plan)
        free_plan = create(:free_plan)

        create(:gitlab_subscription, namespace: ns_gold, hosted_plan: gold_plan)
        create(:gitlab_subscription, namespace: ns_ultimate, hosted_plan: ultimate_plan)
        create(:gitlab_subscription, namespace: ns_trial, hosted_plan: trial_plan)
        create(:gitlab_subscription, namespace: ns_trial_paid, hosted_plan: trial_paid_plan)
        create(:gitlab_subscription, namespace: ns_oss, hosted_plan: oss_plan)
        create(:gitlab_subscription, namespace: ns_free, hosted_plan: free_plan)

        [ns_gold, ns_ultimate, ns_trial, ns_trial_paid, ns_oss, ns_free].each do |ns|
          ns.add_developer(user)
        end

        stub_feature_flags(with_duo_eligible_projects_filter: true)
      end

      it 'returns only projects under eligible plans and with duo toggles enabled' do
        is_expected.to contain_exactly(
          p_gold,
          p_ultimate,
          p_trial,
          p_trial_paid,
          p_oss
        )
      end

      context 'when a project disables duo features locally' do
        before do
          p_ultimate.project_setting.update!(duo_features_enabled: false)
        end

        it 'excludes that project even if the namespace plan is eligible' do
          is_expected.to contain_exactly(p_gold, p_trial, p_trial_paid, p_oss)
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(with_duo_eligible_projects_filter: false)
        end

        it 'does not apply the filter' do
          is_expected.to include(p_gold, p_ultimate, p_trial, p_trial_paid, p_oss, p_free)
        end
      end
    end

    private

    def create_project(plan, visibility = :public)
      create(:project, visibility, namespace: create(:group_with_plan, plan: plan))
    end
  end
end
