# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecret, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let!(:secrets_manager) { create(:project_secrets_manager, :active, project: project) }

  subject(:project_secret) do
    described_class.new(
      project: project,
      name: 'TEST_SECRET',
      branch: 'main',
      environment: 'production'
    )
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:branch) }
    it { is_expected.to validate_presence_of(:environment) }

    describe 'name format' do
      it 'allows valid names' do
        valid_names = %w[SECRET_KEY test_123 ABC123 secret]

        valid_names.each do |name|
          project_secret.name = name
          expect(project_secret).to be_valid
        end
      end

      it 'rejects invalid names' do
        invalid_names = ['secret-key', 'secret.key', 'secret key', '123-secret', 'secret!']

        invalid_names.each do |name|
          project_secret.name = name
          expect(project_secret).not_to be_valid
          expect(project_secret.errors[:name]).to include("can contain only letters, digits and '_'.")
        end
      end
    end

    describe 'secrets manager validation' do
      context 'when project has no secrets manager' do
        before do
          secrets_manager.destroy!
          project.reload
        end

        it 'is invalid' do
          expect(project_secret).not_to be_valid
          expect(project_secret.errors[:base]).to include('Project secrets manager is not active.')
        end
      end

      context 'when secrets manager is not active' do
        before do
          secrets_manager.initiate_deprovision!
        end

        it 'is invalid' do
          expect(project_secret).not_to be_valid
          expect(project_secret.errors[:base]).to include('Project secrets manager is not active.')
        end
      end
    end
  end

  describe 'attributes' do
    it 'has expected attributes' do
      expect(project_secret).to have_attributes(
        name: 'TEST_SECRET',
        branch: 'main',
        environment: 'production',
        project: project,
        metadata_version: 0
      )
    end
  end

  describe 'dirty tracking' do
    it 'tracks changes to branch' do
      expect(project_secret.branch_changed?).to be_falsey

      project_secret.branch = 'feature'
      expect(project_secret.branch_changed?).to be_truthy
      expect(project_secret.branch_was).to eq('main')
    end

    it 'tracks changes to environment' do
      expect(project_secret.environment_changed?).to be_falsey

      project_secret.environment = 'staging'
      expect(project_secret.environment_changed?).to be_truthy
      expect(project_secret.environment_was).to eq('production')
    end
  end

  describe '#==' do
    let(:other_secret) do
      described_class.new(
        project: project,
        name: 'TEST_SECRET',
        branch: 'main',
        environment: 'production'
      )
    end

    it 'returns true for secrets with same attributes' do
      expect(project_secret).to eq(other_secret)
    end

    it 'returns false for secrets with different attributes' do
      other_secret.name = 'DIFFERENT'
      expect(project_secret).not_to eq(other_secret)
    end

    it 'returns false for different object types' do
      expect(project_secret).not_to eq('not a secret')
    end
  end
end
