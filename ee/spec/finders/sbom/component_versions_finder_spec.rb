# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersionsFinder, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  let_it_be(:matching_occurrence) { create(:sbom_occurrence, project: project) }
  let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, project: project) }

  describe '#execute' do
    let(:finder) { described_class.new(project, matching_occurrence.component.id) }

    subject(:find) { finder.execute }

    context 'when `version_filtering_on_project_level_dependency_list` feature flag is enabled' do
      context 'when the component ID has multiple versions' do
        it "returns the versions realted to a component", :aggregate_failures do
          expect(find).to eq([matching_occurrence.component_version])
        end
      end
    end

    context 'when `version_filtering_on_project_level_dependency_list` feature flag is disabled' do
      before do
        stub_feature_flags(version_filtering_on_project_level_dependency_list: false)
      end

      it "returns no versions" do
        expect(find).to be_empty
      end
    end
  end
end
