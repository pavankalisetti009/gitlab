# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Evidences::BuildArtifactEntity do
  include Gitlab::Routing

  subject { described_class.new(build).as_json }

  context 'when job has archive artifact' do
    let(:build) { create(:ci_build, :with_archive_artifact) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Necessary to create build.job_artifacts

    it 'exposes the artifacts url' do
      expect(subject[:url]).to eq(download_project_job_artifacts_url(build.project, build))
    end
  end

  context 'when job does not have archive artifact' do
    let(:build) { build_stubbed(:ci_build) }

    it 'does not expose the artifacts url' do
      expect(subject).not_to include(:url)
    end
  end
end
