# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::BaseSecretsPermission, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  subject(:permission) do
    described_class.new(
      resource: group,
      principal_type: 'User',
      principal_id: user.id,
      permissions: %w[read]
    )
  end

  describe 'abstract methods' do
    let(:principal_group) { create(:group) }

    describe '#find_group_link' do
      it 'raises NotImplementedError' do
        expect { permission.send(:find_group_link, principal_group) }
          .to raise_error(NotImplementedError)
      end
    end

    describe '#resource_type' do
      it 'raises NotImplementedError' do
        expect { permission.send(:resource_type) }
          .to raise_error(NotImplementedError)
      end
    end

    describe '#principal_group_has_access_to_resource?' do
      it 'raises NotImplementedError' do
        expect { permission.send(:principal_group_has_access_to_resource?, principal_group) }
          .to raise_error(NotImplementedError)
      end
    end

    describe '#member_role_has_access_to_resource?' do
      let(:member_role) { create(:member_role, namespace: group) }

      it 'raises NotImplementedError' do
        expect { permission.send(:member_role_has_access_to_resource?, member_role) }
          .to raise_error(NotImplementedError)
      end
    end
  end
end
