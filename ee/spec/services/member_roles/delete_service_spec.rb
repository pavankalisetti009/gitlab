# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::DeleteService, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe '#execute' do
    subject(:result) { service.execute(member_role) }

    shared_examples 'deleting member role' do |audit_event_type, audit_event_message, audit_event_abilities|
      it 'is successful' do
        expect(result).to be_success
      end

      it 'deletes the member role' do
        result

        expect(member_role).to be_destroyed
      end

      include_examples 'audit event logging' do
        let(:licensed_features_to_stub) { { custom_roles: true } }
        let(:event_type) { audit_event_type }
        let(:operation) { result }
        let(:fail_condition!) { allow(member_role).to receive(:destroy).and_return(false) }

        let(:attributes) do
          {
            author_id: user.id,
            entity_id: audit_entity_id,
            entity_type: audit_entity_type,
            details: {
              author_name: user.name,
              target_id: member_role.id,
              target_type: member_role.class.name,
              event_name: audit_event_type,
              target_details: {
                name: member_role.name,
                description: member_role.description,
                abilities: audit_event_abilities
              }.to_s,
              custom_message: audit_event_message,
              author_class: user.class.name
            }
          }
        end
      end
    end

    context 'for self-managed' do
      let_it_be_with_reload(:member_role) { create(:member_role, :guest, :instance) }

      let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
      let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

      context 'with unauthorized user' do
        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with admin', :enable_admin_mode do
        let_it_be(:user) { admin }

        it_behaves_like 'deleting member role', 'member_role_deleted', 'Member role was deleted', 'read_code'

        context 'when the member role is linked to a security policy' do
          before do
            create(:security_policy, content: {
              actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [member_role.id] }]
            })

            stub_licensed_features(security_orchestration_policies: true, custom_roles: true)
          end

          it 'returns error with message' do
            expect(result).to be_error
            expect(result.message).to eq('Custom role linked with a security policy.')
          end
        end

        context 'when failing to destroy the member role' do
          before do
            allow(member_role).to receive(:destroy).and_return(false)
            errors = ActiveModel::Errors.new(member_role).tap { |e| e.add(:base, 'error message') }
            allow(member_role).to receive(:errors).and_return(errors)
          end

          it 'returns an array including the error message' do
            expect(result).to be_error
            expect(result.message).to match_array(['error message'])
          end

          it 'does not log an audit event' do
            expect { result }.not_to change { AuditEvent.count }
          end
        end

        context 'with admin role' do
          let(:member_role) { create(:member_role, :admin) }

          it_behaves_like 'deleting member role', 'admin_role_deleted', 'Admin role was deleted', 'read_admin_dashboard'
        end
      end
    end

    context 'for SaaS', :saas do
      context 'when member role' do
        let_it_be_with_reload(:member_role) { create(:member_role, :guest, namespace: group) }

        let(:audit_entity_id) { group.id }
        let(:audit_entity_type) { group.class.name }

        context 'with unauthorized user' do
          it 'returns an error' do
            expect(result).to be_error
          end
        end

        context 'with owner' do
          before_all do
            group.add_owner(user)
          end

          it_behaves_like 'deleting member role', 'member_role_deleted', 'Member role was deleted', 'read_code'
        end
      end

      context 'with admin role', :enable_admin_mode do
        let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
        let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }
        let(:member_role) { create(:member_role, :admin) }
        let_it_be(:user) { admin }

        it_behaves_like 'deleting member role', 'admin_role_deleted', 'Admin role was deleted', 'read_admin_dashboard'
      end
    end
  end
end
