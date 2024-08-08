# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::PullMirrors::UpdateService, feature_category: :source_code_management do
  subject(:service) { described_class.new(project, user, params) }

  let_it_be_with_reload(:project) { create(:project, :empty_repo) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let(:params) do
    {
      import_url: url,
      mirror: enabled,
      import_data_attributes: {
        auth_method: auth_method,
        user: cred_user,
        password: cred_password
      },
      only_mirror_protected_branches: only_protected_branches
    }
  end

  let(:url) { 'https://example.com' }
  let(:enabled) { true }
  let(:auth_method) { 'password' }
  let(:cred_user) { 'admin' }
  let(:cred_password) { 'pass' }
  let(:only_protected_branches) { true }

  describe '#execute', :aggregate_failures do
    subject(:execute) { service.execute }

    let(:updated_project) { execute.payload[:project] }

    it 'updates a pull mirror' do
      is_expected.to be_success

      expect(updated_project).to have_attributes(
        import_url: "https://#{cred_user}:#{cred_password}@example.com",
        mirror: enabled,
        only_mirror_protected_branches: only_protected_branches,
        id: project.id
      )

      expect(updated_project.import_data).to have_attributes(
        auth_method: auth_method,
        user: cred_user,
        password: cred_password
      )
    end

    it 'triggers a pull mirror update process' do
      expect(UpdateAllMirrorsWorker).to receive(:perform_async)

      is_expected.to be_success
    end

    context 'when user does not have permissions' do
      let(:user) { nil }

      it 'returns an error' do
        is_expected.to be_error
        expect(execute.message).to eq('Access Denied')
      end
    end

    context 'when params are invalid' do
      let(:url) { 'not_a_url' }

      it 'returns an error' do
        is_expected.to be_error
        expect(execute.message.full_messages).to include(/Import url is blocked/)
      end
    end
  end
end
