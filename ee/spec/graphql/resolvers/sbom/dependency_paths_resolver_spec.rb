# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::DependencyPathsResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let_it_be(:ancestor) { create(:sbom_occurrence, project: project) }
  let_it_be(:descendant) do
    create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
      input_file_path: ancestor.input_file_path, project: project)
  end

  subject(:get_paths) { sync(resolve_dependency_paths(args: args)) }

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)

    Sbom::BuildDependencyGraph.execute(project)
  end

  context 'when given a project' do
    let(:project_or_namespace) { project }

    context 'when feature flag is OFF' do
      before do
        stub_feature_flags(dependency_graph_graphql: false)
      end

      let(:args) do
        {
          occurrence: descendant.to_gid
        }
      end

      it { is_expected.to be_nil }
    end

    context 'when feature flag is ON' do
      let(:args) do
        {
          occurrence: descendant.to_gid
        }
      end

      let(:result) do
        [
          {
            path: [descendant],
            is_cyclic: false
          },
          {
            path: [ancestor, descendant],
            is_cyclic: false
          }
        ]
      end

      it 'returns dependency path data' do
        is_expected.to match_array(result)
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
