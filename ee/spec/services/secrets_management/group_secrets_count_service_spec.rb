# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsCountService,
  :gitlab_secrets_manager,
  feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:secrets_manager) { create(:group_secrets_manager, group: group) }

  let(:service) { described_class.new(group, user) }

  before_all do
    group.add_owner(user)
  end

  before do
    provision_group_secrets_manager(secrets_manager, user)
  end

  describe '#execute' do
    subject(:count) { service.execute }

    context 'when there are no secrets' do
      it 'returns 0' do
        expect(count).to eq(0)
      end
    end

    context 'when there are group secrets' do
      before do
        create_group_secret(
          user: user,
          group: group,
          name: 'group_secret1',
          value: 'value1',
          environment: 'production',
          protected: true
        )

        create_group_secret(
          user: user,
          group: group,
          name: 'group_secret2',
          value: 'value2',
          environment: 'staging',
          protected: false
        )
      end

      it 'returns the correct count' do
        expect(count).to eq(2)
      end

      it 'uses the correct data path when listing secrets' do
        client = service.send(:group_secrets_manager_client)
        mount_path = secrets_manager.ci_secrets_mount_path
        data_path = secrets_manager.ci_data_path

        expect(client).to receive(:list_secrets).with(mount_path, data_path).and_call_original

        count
      end
    end
  end
end
