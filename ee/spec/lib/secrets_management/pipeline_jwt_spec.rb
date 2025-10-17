# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::PipelineJwt, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:namespace) { create(:namespace) }
  let_it_be_with_refind(:project) { create(:project, :repository, namespace: namespace) }
  let_it_be(:project_owner) { create(:user, owner_of: project) }
  let_it_be_with_refind(:project_pipeline) do
    create(
      :ci_pipeline,
      project: project,
      sha: project.commit.id,
      ref: project.default_branch,
      status: 'success',
      user: project_owner
    )
  end

  let_it_be_with_refind(:project_build) { create(:ee_ci_build, pipeline: project_pipeline, user: project_owner) }
  let(:aud) { SecretsManagement::ProjectSecretsManager.server_url }

  describe '#payload' do
    subject(:payload) do
      described_class.new(project_build, ttl: 30, aud: aud, sub_components: [], target_audience: nil).payload
    end

    it 'includes the correct claims' do
      expect(payload[:secrets_manager_scope]).to eq('pipeline')
      expect(payload[:aud]).to eq(aud)
      expect(payload[:project_id]).to eq(project.id.to_s)
      expect(payload[:job_id]).to eq(project_build.id.to_s)
    end
  end
end
