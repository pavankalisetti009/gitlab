# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::DependencyPathsResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let_it_be(:component) { create(:sbom_component, name: "activestorage") }

  subject(:get_paths) { sync(resolve_dependency_paths(args: args)) }

  context 'when given a project' do
    let(:project_or_namespace) { project }

    context 'when feature flag is OFF' do
      before do
        stub_feature_flags(dependency_graph_graphql: false)
      end

      let(:args) do
        {
          component: component.to_gid
        }
      end

      it { is_expected.to be_nil }

      it 'does not record metrics' do
        expect(Gitlab::Metrics).not_to receive(:measure)
      end
    end

    context 'when feature flag is ON' do
      before do
        stub_feature_flags(dependency_graph_graphql: true)
      end

      let(:args) do
        {
          component: component.to_gid
        }
      end

      let(:result) do
        [Sbom::DependencyPath.new(
          id: component.id,
          project_id: project.id,
          dependency_name: component.name,
          full_path: %w[ancestor_1 ancestor_2 dependency],
          version: ['0.0.1', '0.0.2', '0.0.3'],
          is_cyclic: false,
          max_depth_reached: false
        )]
      end

      it 'returns data from DependencyPath.find' do
        expect(::Sbom::DependencyPath).to receive(:find)
          .with(id: component.id.to_s, project_id: project.id)
          .and_return(result)
        is_expected.to eq(result)
      end

      it 'records execution time' do
        expect(::Sbom::DependencyPath).to receive(:find)
          .with(id: component.id.to_s, project_id: project.id)
          .and_return(result)
        expect(Gitlab::Metrics).to receive(:measure)
          .with(:dependency_path_cte)
          .and_call_original

        get_paths
      end

      it 'records metrics' do
        expect(::Sbom::DependencyPath).to receive(:find)
          .with(id: component.id.to_s, project_id: project.id)
          .and_return(result)
        counter_double = instance_double(Prometheus::Client::Counter)
        expect(Gitlab::Metrics).to receive(:counter)
          .with(:dependency_path_cte_paths_found, 'Count of Dependency Paths found using the recursive CTE')
          .and_return(counter_double)

        expect(counter_double).to receive(:increment)
          .with({ cyclic: false, max_depth_reached: false }, 1)
        expect(counter_double).to receive(:increment)
          .with({ cyclic: false, max_depth_reached: true }, 0)
        expect(counter_double).to receive(:increment)
          .with({ cyclic: true, max_depth_reached: false }, 0)
        expect(counter_double).to receive(:increment)
          .with({ cyclic: true, max_depth_reached: true }, 0)

        get_paths
      end
    end
  end

  private

  def resolve_dependency_paths(args: {})
    resolve(
      described_class,
      obj: project_or_namespace,
      args: args,
      ctx: { current_user: user }
    )
  end
end
