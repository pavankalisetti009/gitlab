# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::Projects::CreatorService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:source) { create(:project) }
  let(:existing_role) { :guest }
  let!(:existing_member) { create(:project_member, existing_role, user: user, project: source) }

  describe '.add_member' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management feature'
    end

    context 'with the licensed feature for disable_invite_members' do
      let_it_be(:role) { :developer }
      let_it_be(:added_user) { create(:user) }

      shared_examples 'successful member creation' do
        it 'creates a new member' do
          member = described_class.add_member(source, added_user, role, current_user: current_user)
          expect(member).to be_persisted
        end
      end

      shared_examples 'failed member creation' do
        it 'does not create a new member' do
          member = described_class.add_member(source, added_user, role, current_user: current_user)
          expect(member).not_to be_persisted
          expect(member.errors.full_messages).to include(/not authorized to create member/)
        end
      end

      context 'when the user is a project maintainer' do
        let_it_be(:current_user) { create(:user) }

        before_all do
          source.add_maintainer(current_user)
        end

        context 'and the licensed feature is available' do
          before do
            stub_licensed_features(disable_invite_members: true)
          end

          context 'and the setting disable_invite_members is ON' do
            before do
              stub_application_setting(disable_invite_members: true)
            end

            it_behaves_like 'failed member creation'
          end

          context 'and the setting disable_invite_members is OFF' do
            before do
              stub_application_setting(disable_invite_members: false)
            end

            it_behaves_like 'successful member creation'
          end
        end

        context 'and the licensed feature is unavailable' do
          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like 'successful member creation'
        end
      end

      context 'when the user is an admin and the setting disable_invite_members is ON' do
        let_it_be(:current_user) { create(:admin) }

        before do
          stub_licensed_features(disable_invite_members: true)
          stub_application_setting(disable_invite_members: true)
        end

        context 'with admin mode enabled', :enable_admin_mode do
          it_behaves_like 'successful member creation'
        end

        it_behaves_like 'failed member creation'
      end
    end
  end

  describe '.add_members' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management for multiple users'
    end
  end

  describe 'service account membership eligibility' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:service_account_user) { create(:user, :service_account) }

    before_all do
      source.add_owner(current_user)
    end

    context 'when adding a regular user' do
      let(:added_user) { create(:user) }

      it 'creates the member successfully' do
        member = described_class.add_member(source, added_user, :developer, current_user: current_user)
        expect(member).to be_persisted
      end
    end

    context 'when adding a service account' do
      let_it_be(:project_namespace) { source.namespace }

      context 'and the service account is eligible for membership' do
        it 'creates the member successfully and calls MembershipEligibilityChecker with target_project' do
          allow(::Members::ServiceAccounts::EligibilityChecker)
            .to receive(:new).with(target_project: source).and_call_original
          expect_next_instance_of(::Members::ServiceAccounts::EligibilityChecker) do |instance|
            expect(instance).to receive(:eligible?).with(service_account_user).and_return(true)
          end

          member = described_class.add_member(source, service_account_user, :developer, current_user: current_user)
          expect(member).to be_persisted
        end
      end

      context 'and the service account is not eligible for membership' do
        it 'does not create the member' do
          expect_next_instance_of(::Members::ServiceAccounts::EligibilityChecker) do |instance|
            expect(instance).to receive(:eligible?).with(service_account_user).and_return(false)
          end

          member = described_class.add_member(source, service_account_user, :developer, current_user: current_user)
          expect(member).not_to be_persisted
          expect(member.errors.full_messages).to include(/not authorized to create member/)
        end
      end
    end

    context 'when current user lacks admin_project_member permission' do
      let(:current_user) { create(:user) }

      it 'does not create the member even if service account is eligible' do
        expect_next_instance_of(::Members::ServiceAccounts::EligibilityChecker) do |instance|
          expect(instance).to receive(:eligible?).and_return(true)
        end

        member = described_class.add_member(source, service_account_user, :developer, current_user: current_user)
        expect(member).not_to be_persisted
        expect(member.errors.full_messages).to include(/not authorized to create member/)
      end
    end
  end
end
