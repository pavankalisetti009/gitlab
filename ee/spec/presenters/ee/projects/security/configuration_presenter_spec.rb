# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ConfigurationPresenter, feature_category: :software_composition_analysis do
  include Gitlab::Routing.url_helpers
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, maintainers: current_user) }

  let(:presenter) { described_class.new(project, current_user: current_user) }

  describe '#to_h' do
    subject(:result) { presenter.to_h }

    it 'includes the vulnerability archive export path' do
      expect(result[:vulnerability_archive_export_path]).to eq(
        "/api/v4/security/projects/#{project.id}/vulnerability_archive_exports"
      )
    end

    it 'reports security_training_enabled' do
      allow(project).to receive(:security_training_available?).and_return(true)

      expect(result[:security_training_enabled]).to be_truthy
    end

    it 'includes a default value for container_scanning_for_registry_enabled' do
      expect(result[:container_scanning_for_registry_enabled]).to eq(false)
    end

    it 'includes a default value for secret_push_protection_enabled' do
      expect(result[:secret_push_protection_enabled]).to eq(false)
    end

    it 'includes a default value for validity_checks_enabled' do
      expect(result[:validity_checks_enabled]).to eq(false)
    end

    it 'includes validity_checks_available' do
      expect(result).to have_key(:validity_checks_available)
    end

    it 'includes license_configuration_source' do
      expect(result[:license_configuration_source]).to eq('SBOM')
    end

    it 'includes can_enable_spp' do
      expect(result).to have_key(:can_enable_spp)
    end

    it 'includes secret_push_protection_licensed' do
      expect(result).to have_key(:secret_push_protection_licensed)
    end

    it 'includes is_gitlab_com' do
      expect(result).to have_key(:is_gitlab_com)
    end

    it 'includes user_is_project_admin' do
      expect(result).to have_key(:user_is_project_admin)
    end

    context 'when security setting is nil' do
      before do
        allow(project).to receive(:security_setting).and_return(nil)
      end

      it 'returns the default value' do
        expect(result[:license_configuration_source]).to eq('SBOM')
      end
    end

    context 'with ultimate license' do
      before do
        stub_licensed_features(secret_push_protection: true)
      end

      it 'sets can_enable_spp to true' do
        expect(result[:can_enable_spp]).to be(true)
      end

      it 'sets secret_push_protection_licensed to true' do
        expect(result[:secret_push_protection_licensed]).to be(true)
      end
    end

    context 'without ultimate license' do
      before do
        stub_licensed_features(secret_push_protection: false)
      end

      it 'sets secret_push_protection_licensed to false' do
        expect(result[:secret_push_protection_licensed]).to be(false)
      end

      context 'on GitLab.com', :saas do
        context 'when project is public' do
          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
          end

          it 'sets can_enable_spp to true for public projects' do
            expect(result[:can_enable_spp]).to be(true)
          end
        end

        context 'when project is private' do
          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          end

          it 'sets can_enable_spp to false for private projects' do
            expect(result[:can_enable_spp]).to be(false)
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(auto_spp_public_com_projects: false)
            project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
          end

          it 'sets can_enable_spp to false even for public projects' do
            expect(result[:can_enable_spp]).to be(false)
          end
        end
      end

      context 'when not on GitLab.com' do
        before do
          stub_saas_features(auto_enable_secret_push_protection_public_projects: false)
        end

        it 'sets can_enable_spp to false' do
          expect(result[:can_enable_spp]).to be(false)
        end
      end
    end

    context 'when user is not a maintainer or owner' do
      before_all do
        project.members.find_by(user: current_user)&.destroy!
        project.add_developer(current_user)
      end

      before do
        stub_licensed_features(secret_push_protection: true)
      end

      it 'sets can_enable_spp to false' do
        expect(result[:can_enable_spp]).to be(false)
      end
    end

    describe 'secret_push_protection_available' do
      context 'when instance setting is enabled' do
        before do
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:secret_push_protection_available).and_return(true)
        end

        it 'returns true' do
          expect(result[:secret_push_protection_available]).to be(true)
        end
      end

      context 'when instance setting is disabled' do
        before do
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:secret_push_protection_available).and_return(false)
        end

        it 'returns false' do
          expect(result[:secret_push_protection_available]).to be(false)
        end
      end
    end
  end

  describe '#to_html_data_attribute' do
    subject(:html_data) { presenter.to_html_data_attribute }

    before do
      stub_licensed_features(container_scanning_for_registry: true)
    end

    it 'includes container_scanning_for_registry feature information' do
      feature = Gitlab::Json.parse(html_data[:features]).find do |scan|
        scan['type'] == 'container_scanning_for_registry'
      end

      expect(feature['type']).to eq('container_scanning_for_registry')
      expect(feature['configured']).to eq(false)
      expect(feature['configuration_path']).to be_nil
      expect(feature['available']).to eq(true)
      expect(feature['can_enable_by_merge_request']).to eq(false)
      expect(feature['meta_info_path']).to be_nil
      expect(feature['security_features']).not_to be_empty
    end

    it 'includes can_enable_spp in the data' do
      expect(html_data).to have_key(:can_enable_spp)
    end

    it 'includes secret_push_protection_licensed in the data' do
      expect(html_data).to have_key(:secret_push_protection_licensed)
    end

    it 'includes is_gitlab_com in the data' do
      expect(html_data).to have_key(:is_gitlab_com)
    end
  end
end
