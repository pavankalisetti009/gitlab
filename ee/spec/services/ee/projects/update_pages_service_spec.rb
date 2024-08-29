# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdatePagesService, feature_category: :pages do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:path_prefix) { nil }
  let(:build_options) { { pages: { path_prefix: path_prefix } } }
  let(:build) { create(:ci_build, :pages, project: project, user: user, options: build_options) }

  subject(:service) { described_class.new(project, build) }

  before_all do
    project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
  end

  before do
    stub_pages_setting(enabled: true)
  end

  context 'when path_prefix is not blank' do
    let(:path_prefix) { '/path_prefix/' }

    context 'and pages_multiple_versions is disabled for project' do
      before do
        allow(::Gitlab::Pages)
          .to receive(:multiple_versions_enabled_for?)
          .with(build.project)
          .and_return(false)
      end

      it 'does not create a new pages_deployment' do
        expect { expect(service.execute).to include(status: :error) }
          .not_to change { project.pages_deployments.count }
      end

      it_behaves_like 'internal event not tracked' do
        let(:event) { 'create_pages_extra_deployment' }

        subject(:track_event) { service.execute }
      end
    end

    context 'and pages_multiple_versions is enabled for project' do
      before do
        allow(::Gitlab::Pages)
          .to receive(:multiple_versions_enabled_for?)
          .with(build.project)
          .and_return(true)
        stub_application_setting(pages_extra_deployments_default_expiry_seconds: 3600)
      end

      it 'saves the slugiffied version of the path prefix' do
        expect { expect(service.execute).to include(status: :success) }
          .to change { project.pages_deployments.count }.by(1)

        expect(project.pages_deployments.last.path_prefix).to eq('path-prefix')
      end

      it 'sets the expiry date to the default setting', :freeze_time do
        expect { expect(service.execute).to include(status: :success) }
          .to change { project.pages_deployments.count }.by(1)

        expect(project.pages_deployments.last.expires_at).to eq(1.hour.from_now)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'create_pages_extra_deployment' }
        let(:category) { 'Projects::UpdatePagesService' }
        let(:namespace) { project.namespace }

        subject(:track_event) { service.execute }
      end
    end
  end

  context 'when path_prefix is blank' do
    let(:path_prefix) { '' }

    context 'and pages_multiple_versions is enabled for project' do
      before do
        allow(::Gitlab::Pages)
          .to receive(:multiple_versions_enabled_for?)
            .with(build.project)
            .and_return(true)
        stub_application_setting(pages_extra_deployments_default_expiry_seconds: 3600)
      end

      it 'does not set an expiry date', :freeze_time do
        expect { expect(service.execute).to include(status: :success) }
          .to change { project.pages_deployments.count }.by(1)

        expect(project.pages_deployments.last.expires_at).to be_nil
      end
    end
  end
end
