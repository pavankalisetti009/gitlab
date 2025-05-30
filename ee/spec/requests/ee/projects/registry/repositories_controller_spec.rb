# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Registry::RepositoriesController, feature_category: :container_registry do
  let_it_be(:project) { create(:project) }
  let(:user) { project.creator }

  before do
    stub_container_registry_config(enabled: true, key: 'spec/fixtures/x509_certificate_pk.key')
    stub_container_registry_info

    sign_in(user)
    allow(Auth::ContainerRegistryAuthenticationService).to receive(:access_token).with({}).and_return('foo')
  end

  describe 'GET #index' do
    subject { get project_container_registry_index_path(project) }

    it_behaves_like 'pushed feature flag', :container_registry_immutable_tags
  end

  describe 'GET #show' do
    let_it_be(:container_repository) { create(:container_repository, :root, project:) }

    subject { get project_container_registry_path(project, container_repository) }

    it_behaves_like 'pushed feature flag', :container_registry_immutable_tags
  end
end
