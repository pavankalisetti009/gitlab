# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyEntity, feature_category: :dependency_management do
  describe '#as_json' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository, :private, :in_group) }
    let_it_be(:group) { project.group }
    let_it_be(:sbom_occurrence) { create(:sbom_occurrence, :mit, :bundler, :with_ancestors, project: project) }
    let(:request_params) { { project: project, group: group, user: user } }
    let(:request) { EntityRequest.new(**request_params) }
    let(:params) { { request: request } }

    subject { described_class.represent(sbom_occurrence, request: request).as_json }

    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true, license_scanning: true)
    end

    it 'renders the proper representation' do
      expect(subject.as_json).to eq({
        "name" => sbom_occurrence.name,
        "occurrence_count" => 1,
        "packager" => sbom_occurrence.packager,
        "project_count" => 1,
        "version" => sbom_occurrence.version,
        "licenses" => sbom_occurrence.licenses,
        "component_id" => sbom_occurrence.component_version_id,
        "vulnerability_count" => 0,
        "occurrence_id" => sbom_occurrence.id
      })
    end

    context "when there are no licenses" do
      let_it_be(:sbom_occurrence) { create(:sbom_occurrence, project: project) }

      it 'returns an empty array' do
        expect(subject.as_json['licenses']).to eq([])
      end
    end

    context 'when all required features are unavailable' do
      before do
        stub_licensed_features(security_dashboard: false, license_scanning: false)
      end

      it 'does not include licenses and vulnerabilities' do
        is_expected.not_to match(hash_including(:vulnerabilities, :licenses))
      end
    end
  end
end
