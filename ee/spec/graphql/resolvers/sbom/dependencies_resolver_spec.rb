# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::DependenciesResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }
  let_it_be(:project_1) { create(:project, namespace: namespace) }
  let_it_be(:project_2) { create(:project, namespace: namespace) }

  let_it_be(:component_1) { create(:sbom_component, name: "activestorage") }
  let_it_be(:occurrence_1) { create(:sbom_occurrence, component: component_1, project: project_1) }

  let_it_be(:component_2) { create(:sbom_component, name: "activesupport") }
  let_it_be(:occurrence_2) { create(:sbom_occurrence, component: component_2, project: project_1) }
  let_it_be(:occurrence_3) { create(:sbom_occurrence, component: component_2, project: project_2) }

  subject { sync(resolve_dependencies(args: args)) }

  context 'when given a project' do
    let(:project_or_namespace) { project_1 }

    context 'when given component_ids' do
      let(:args) do
        {
          component_ids: [component_1.to_gid]
        }
      end

      it { is_expected.to match_array([occurrence_1]) }
    end
  end

  context 'when given a namespace' do
    let(:project_or_namespace) { namespace }

    context 'when given component_ids' do
      let(:args) do
        {
          component_ids: [component_2.to_gid]
        }
      end

      it { is_expected.to match_array([occurrence_2, occurrence_3]) }
    end
  end

  private

  def resolve_dependencies(args: {})
    resolve(
      described_class,
      obj: project_or_namespace,
      args: args,
      ctx: { current_user: user }
    )
  end
end
