# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::UpdateService, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let(:user) { regular_user }

  describe '#execute' do
    let(:existing_abilities) { { read_vulnerability: true } }
    let(:updated_abilities) { { read_vulnerability: false, read_code: true } }
    let(:params) do
      {
        name: 'new name',
        description: 'new description',
        base_access_level: Gitlab::Access::DEVELOPER,
        **updated_abilities
      }
    end

    subject(:result) { described_class.new(user, params).execute(member_role) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    shared_examples 'member role update' do |audit_event_type, audit_event_message|
      context 'with valid params' do
        it 'is successful' do
          expect(result).to be_success
        end

        it 'updates the provided (permitted) attributes' do
          expect { result }
            .to change { member_role.reload.name }.to('new name')
            .and change { member_role.reload.permissions[existing_abilities.each_key.first.to_s] }.to(false)
        end

        it 'does not update unpermitted attributes' do
          expect { result }.not_to change { member_role.reload.base_access_level }
        end

        include_examples 'audit event logging' do
          let(:licensed_features_to_stub) { { custom_roles: true } }
          let(:event_type) { audit_event_type }
          let(:operation) { result }
          let(:fail_condition!) { allow(member_role).to receive(:save).and_return(false) }

          let(:attributes) do
            {
              author_id: user.id,
              entity_id: audit_entity_id,
              entity_type: audit_entity_type,
              details: {
                author_name: user.name,
                event_name: audit_event_type,
                target_id: member_role.id,
                target_type: member_role.class.name,
                target_details: {
                  name: 'new name',
                  description: 'new description',
                  abilities: updated_abilities.filter { |_, v| v }.keys.join(', ')
                }.to_s,
                custom_message: audit_event_message,
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
      let(:member_role) { create(:member_role, :guest, :instance, **existing_abilities) }

      let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
      let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

      context 'with unauthorized user' do
        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with authorized user', :enable_admin_mode do
        let(:user) { admin }

        it_behaves_like 'member role update', 'member_role_updated', 'Member role was updated'

        context 'with admin roles' do
          let(:existing_abilities) { { read_admin_dashboard: true } }
          let(:updated_abilities) { { read_admin_dashboard: false, read_admin_users: true } }
          let(:member_role) { create(:member_role, :admin, **existing_abilities) }

          it_behaves_like 'member role update', 'admin_role_updated', 'Admin role was updated'
        end
      end
    end

    context 'for SaaS', :saas do
      context 'when member role' do
        let(:member_role) { create(:member_role, :guest, namespace: group, **existing_abilities) }

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

          it_behaves_like 'member role update', 'member_role_updated', 'Member role was updated'
        end
      end

      context 'when admin role', :enable_admin_mode do
        let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
        let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

        let(:existing_abilities) { { read_admin_dashboard: true } }
        let(:updated_abilities) { { read_admin_dashboard: false, read_admin_users: true } }
        let(:member_role) { create(:member_role, :admin, **existing_abilities) }

        context 'with unauthorized user' do
          let(:user) { regular_user }

          it 'returns an error' do
            expect(result).to be_error
          end
        end

        context 'with authorized user' do
          let(:user) { admin }

          it_behaves_like 'member role update', 'admin_role_updated', 'Admin role was updated'
        end
      end
    end
  end
end
