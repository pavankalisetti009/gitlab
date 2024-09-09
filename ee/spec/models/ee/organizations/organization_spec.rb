# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Organization, feature_category: :cell do
  let_it_be_with_reload(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization) }

  describe 'associations' do
    it { is_expected.to have_many(:sbom_occurrences).through(:active_projects).class_name('Sbom::Occurrence') }
    it { is_expected.to have_many(:vulnerability_exports).class_name('Vulnerabilities::Export') }
    it { is_expected.to have_many(:sbom_sources).class_name('Sbom::Source') }
    it { is_expected.to have_many(:sbom_source_packages).class_name('Sbom::SourcePackage') }
    it { is_expected.to have_many(:sbom_components).class_name('Sbom::Component') }
    it { is_expected.to have_many(:sbom_component_versions).class_name('Sbom::ComponentVersion') }
  end

  describe '#sbom_occurrences' do
    subject(:sbom_occurrences) { organization.sbom_occurrences }

    context 'when a project is active' do
      let_it_be(:occurrence_from_active_project) { create(:sbom_occurrence, project: project) }

      it 'includes the occurrences from the project' do
        expect(sbom_occurrences).to include(occurrence_from_active_project)
      end
    end

    context 'when a project is archived' do
      let_it_be(:archived_project) { create(:project, :archived, organization: organization) }
      let_it_be(:occurrence_from_archived_project) { create(:sbom_occurrence, project: archived_project) }

      it 'does not includes the occurrences from the archived project' do
        expect(sbom_occurrences).not_to include(occurrence_from_archived_project)
      end
    end
  end

  describe '#has_dependencies?' do
    subject { organization.has_dependencies? }

    it 'returns false when organization does not have dependencies' do
      is_expected.to eq(false)
    end

    it 'returns true when organization does have dependencies' do
      create(:sbom_occurrence, project: project)

      is_expected.to eq(true)
    end
  end
end
