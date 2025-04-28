# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersionsFinder, feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }

  let_it_be(:sbom_component) { create(:sbom_component) }
  let_it_be(:matching_occurrence1) { create(:sbom_occurrence, component: sbom_component, project: project) }
  let_it_be(:matching_occurrence2) { create(:sbom_occurrence, component: sbom_component, project: project) }
  let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, project: project) }

  describe '#execute' do
    shared_examples 'when the component has multiple versions' do
      it "returns the versions related to a component" do
        expect(find).to match_array([matching_occurrence1.component_version, matching_occurrence2.component_version])
      end
    end

    shared_examples 'no versions' do
      it "returns no versions" do
        expect(find).to be_empty
      end
    end

    let(:finder) { described_class.new(object, sbom_component.name) }

    subject(:find) { finder.execute }

    context 'when finding versions for project' do
      let(:object) { project }

      context 'when `version_filtering_on_project_level_dependency_list` feature flag is enabled' do
        it_behaves_like 'when the component has multiple versions'
      end

      context 'when `version_filtering_on_project_level_dependency_list` feature flag is disabled' do
        before do
          stub_feature_flags(version_filtering_on_project_level_dependency_list: false)
        end

        it_behaves_like 'no versions'
      end
    end

    context 'when finding versions for group' do
      let(:object) { group }

      context 'when `version_filtering_on_group_level_dependency_list` feature flag is enabled' do
        it_behaves_like 'when the component has multiple versions'
      end

      context 'when `version_filtering_on_group_level_dependency_list` feature flag is disabled' do
        before do
          stub_feature_flags(version_filtering_on_group_level_dependency_list: false)
        end

        it_behaves_like 'no versions'
      end
    end
  end
end
