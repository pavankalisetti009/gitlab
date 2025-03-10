# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::UpdateService, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let(:user) { regular_user }

  describe '#execute' do
    let(:params) do
      {
        name: 'new name',
        description: 'new description',
        read_vulnerability: false,
        read_code: true,
        base_access_level: Gitlab::Access::DEVELOPER
      }
    end

    subject(:result) { described_class.new(user, params).execute(member_role) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    shared_examples 'member role update' do
      context 'with valid params' do
        it 'is successful' do
          expect(result).to be_success
        end

        it 'updates the provided (permitted) attributes' do
          expect { result }
            .to change { member_role.reload.name }.to('new name')
                                                  .and change { member_role.reload.read_vulnerability }.to(false)
        end

        it 'does not update unpermitted attributes' do
          expect { result }.not_to change { member_role.reload.base_access_level }
        end

        include_examples 'audit event logging' do
          let(:licensed_features_to_stub) { { custom_roles: true } }
          let(:event_type) { 'member_role_updated' }
          let(:operation) { result }
          let(:fail_condition!) { allow(member_role).to receive(:save).and_return(false) }

          let(:attributes) do
            {
              author_id: user.id,
              entity_id: audit_entity_id,
              entity_type: audit_entity_type,
              details: {
                author_name: user.name,
                event_name: 'member_role_updated',
                target_id: member_role.id,
                target_type: member_role.class.name,
                target_details: {
                  name: 'new name',
                  description: 'new description',
                  abilities: 'read_code'
                }.to_s,
                custom_message: 'Member role was updated',
                author_class: user.class.name
              }
            }
          end
        end
      end

      context 'when member role can not be updated' do
        before do
          error_messages = double

          allow(member_role).to receive(:save).and_return(false)
          allow(member_role).to receive(:errors).and_return(error_messages)
          allow(error_messages).to receive(:full_messages).and_return(['this is wrong'])
        end

        it 'is not successful' do
          expect(result).to be_error
        end

        it 'includes the object errors' do
          expect(result.message).to eq(['this is wrong'])
        end

        it 'does not log an audit event' do
          expect { result }.not_to change { AuditEvent.count }
        end
      end
    end

    context 'for self-managed' do
      let_it_be(:member_role) { create(:member_role, :guest, :instance, read_vulnerability: true) }

      let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
      let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

      context 'with unauthorized user' do
        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with authorized user', :enable_admin_mode do
        let(:user) { admin }

        it_behaves_like 'member role update'
      end
    end

    context 'for SaaS', :saas do
      let_it_be(:member_role) { create(:member_role, :guest, namespace: group, read_vulnerability: true) }

      let(:audit_entity_id) { group.id }
      let(:audit_entity_type) { group.class.name }

      context 'with unauthorized user' do
        before_all do
          group.add_maintainer(regular_user)
        end

        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with authorized user' do
        before_all do
          group.add_owner(regular_user)
        end

        it_behaves_like 'member role update'
      end
    end
  end
end
