# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::BaseDeleteService, feature_category: :user_management do
  let(:test_service_class) do
    Class.new(described_class) do
      private

      def user_provisioned_resource
        user.provisioned_by_group
      end
    end
  end

  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }

  let(:service_account_user) { create(:service_account, provisioned_by_group: group) }

  let(:current_user) { admin }
  let(:options) { { hard_delete: false } }

  subject(:service) { test_service_class.new(current_user, service_account_user) }

  before_all do
    group.add_owner(owner)
    group.add_maintainer(maintainer)
  end

  before do
    stub_licensed_features(service_accounts: true)
  end

  shared_examples 'service account deletion success' do
    it 'deletes service account successfully', :sidekiq_inline, :aggregate_failures do
      result = perform_enqueued_jobs { service.execute(options) }

      expect(result.status).to eq(:success)
      expect(result.message).to eq('User successfully deleted')
      expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: current_user)).to exist
      expect(service_account_user.reload.blocked?).to be(true)
    end
  end

  shared_examples 'service account deletion failure' do
    it 'returns forbidden error', :aggregate_failures do
      result = service.execute(options)

      expect(result.status).to eq(:error)
      expect(result.message).to eq(s_('ServiceAccount|User does not have permission to delete a service account.'))
      expect(result.reason).to eq(:forbidden)
    end
  end

  describe 'abstract method enforcement' do
    let(:base_service) { described_class.new(current_user, service_account_user) }

    it 'raises Gitlab::AbstractMethodError for #user_provisioned_resource' do
      expect { base_service.execute(options) }
        .to raise_error(Gitlab::AbstractMethodError)
    end
  end

  describe '#execute' do
    context 'when current user is an admin' do
      let(:current_user) { admin }

      context 'when admin mode is not enabled' do
        it_behaves_like 'service account deletion failure'
      end

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'service account deletion success'
      end
    end

    context 'when current user is a group owner' do
      let(:current_user) { owner }

      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it_behaves_like 'service account deletion success'

      context 'when application setting is disabled' do
        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
        end

        it_behaves_like 'service account deletion failure'
      end
    end

    context 'when current user is a maintainer' do
      let(:current_user) { maintainer }

      it_behaves_like 'service account deletion failure'
    end

    context 'when provisioned resource is nil' do
      let(:service_account_user) { create(:service_account) }

      it_behaves_like 'service account deletion failure'
    end

    context 'when user has errors' do
      before do
        allow(service_account_user).to receive(:run_after_commit_or_now)
        service_account_user.errors.add(:base, 'Some error occurred')
      end

      it 'returns error with messages', :enable_admin_mode, :aggregate_failures do
        result = service.execute(options)

        expect(result.status).to eq(:error)
        expect(result.message).to include('Some error occurred')
        expect(result.reason).to eq(:bad_request)
      end
    end
  end
end
