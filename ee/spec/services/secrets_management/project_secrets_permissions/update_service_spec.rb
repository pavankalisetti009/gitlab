# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe SecretsManagement::ProjectSecretsPermissions::UpdateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:resource) { project }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service) { described_class.new(project, user) }

  before_all do
    project.add_owner(user)
  end

  def provision_secrets_manager(secrets_manager, user)
    provision_project_secrets_manager(secrets_manager, user)
  end

  it_behaves_like 'a service for updating secrets permissions', 'project'
end
