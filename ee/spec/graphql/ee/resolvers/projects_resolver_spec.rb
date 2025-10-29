# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ProjectsResolver, feature_category: :groups_and_projects do
  include GraphqlHelpers

  describe '#resolve' do
    subject { resolve(described_class, obj: nil, args: filters, ctx: { current_user: user }).items }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, developers: user) }
    let_it_be(:marked_for_deletion_on) { Date.yesterday }
    let_it_be(:hidden_project) { create(:project, :hidden, developers: user) }

    let_it_be(:project_marked_for_deletion) do
      create(:project, marked_for_deletion_at: marked_for_deletion_on, developers: user)
    end

    let(:filters) { {} }

    before do
      ::Current.organization = project.organization
    end

    context 'when includeHidden filter is true' do
      let(:filters) { { include_hidden: true } }

      it do
        is_expected.to contain_exactly(project, hidden_project, project_marked_for_deletion)
      end
    end

    context 'when includeHidden filter is false' do
      let(:filters) { { include_hidden: false } }

      it { is_expected.to contain_exactly(project, project_marked_for_deletion) }
    end

    context 'when requesting with_code_embeddings_indexed' do
      let!(:filters) { { with_code_embeddings_indexed: true } }

      let_it_be(:namespace) { create(:group) }
      let_it_be(:code_embeddings_enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, namespace: namespace)
      end

      let!(:code_embeddings_repository) do
        create(
          :ai_active_context_code_repository,
          project: project,
          enabled_namespace: code_embeddings_enabled_namespace
        )
      end

      it 'raises error when called with with_code_embeddings_indexed and without ids' do
        resolve = resolve(described_class, obj: nil, args: filters, ctx: { current_user: user })
        expect(resolve).to be_a(Gitlab::Graphql::Errors::ArgumentError)
        expect(resolve.message).to eq('with_code_embeddings_indexed should be only used with ids')
      end

      context 'when there are active code_embeddings_repository' do
        let!(:filters) { { with_code_embeddings_indexed: true, ids: [project.to_global_id.to_s] } }

        before do
          code_embeddings_repository.active_context_connection.update!(active: true)
          code_embeddings_repository.update!(state: :ready)
        end

        it 'returns projects with active code_embeddings_repository' do
          is_expected.to contain_exactly(project)
        end
      end
    end

    context 'when requesting with_duo_eligible', :saas do
      let(:filters) { { with_duo_eligible: true } }

      it { is_expected.to be_empty }

      context 'with eligible project and namespace' do
        let!(:ns_ultimate) { create(:group_with_plan, plan: :ultimate_plan) }
        let!(:p_ultimate) { create(:project, namespace: ns_ultimate) }

        before do
          p_ultimate.project_setting.update!(duo_features_enabled: true)
          ns_ultimate.namespace_settings.update!(experiment_features_enabled: true)
          stub_feature_flags(with_duo_eligible_projects_filter: true)
          ns_ultimate.add_developer(user)
        end

        it { is_expected.to contain_exactly(p_ultimate) }
      end
    end
  end
end
