# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::CreateProjectSecretService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  let(:service) { described_class.new(project) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:value) { 'the-secret-value' }

  subject(:result) { service.execute(name: name, description: description, value: value) }

  describe '#execute', :aggregate_failures do
    context 'when the project secrets manager is active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        provision_project_secrets_manager(secrets_manager)
      end

      it 'creates a project secret' do
        expect(result).to be_success

        secret = result.payload[:project_secret]
        expect(secret).to be_present
        expect(secret.name).to eq(name)
        expect(secret.description).to eq(description)
        expect(secret.project).to eq(project)

        expect_kv_secret_to_have_value(project.secrets_manager.ci_secrets_mount_path, name, value)
        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.ci_secrets_mount_path,
          name,
          "description" => description
        )
      end

      context 'when the secret already exists' do
        before do
          described_class.new(project).execute(name: name, value: value)
        end

        it 'fails' do
          expect(result).to be_error
          expect(result.message).to eq('Project secret already exists.')
        end
      end
    end

    context 'when the project secrets manager is not active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active.')
      end
    end

    context 'when the project has not enabled secrets manager at all' do
      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active.')
      end
    end
  end
end
