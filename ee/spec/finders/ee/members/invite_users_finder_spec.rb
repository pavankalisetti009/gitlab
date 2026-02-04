# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::InviteUsersFinder, feature_category: :groups_and_projects do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:organization) { current_user.organization }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, namespace: root_group, creator: current_user) }

  before_all do
    root_group.add_owner(current_user)
  end

  subject(:finder) do
    described_class.new(current_user, resource, organization_id: organization.id)
  end

  describe '#execute' do
    describe 'MembershipEligibilityChecker integration' do
      context 'when resource is a group' do
        let(:resource) { root_group }

        it 'passes target_group to MembershipEligibilityChecker' do
          expect(::Members::ServiceAccounts::EligibilityChecker)
            .to receive(:new).with(target_group: root_group).and_call_original

          finder.execute
        end
      end

      context 'when resource is a project' do
        let(:resource) { project }

        it 'passes target_project to MembershipEligibilityChecker' do
          expect(::Members::ServiceAccounts::EligibilityChecker)
            .to receive(:new).with(target_project: project).and_call_original

          finder.execute
        end
      end

      context 'when resource is neither Group nor Project' do
        let(:resource) do
          double(root_ancestor: double(group_namespace?: false)) # rubocop:disable RSpec/VerifiedDoubles -- mock only
        end

        it 'passes no arguments to MembershipEligibilityChecker' do
          expect(::Members::ServiceAccounts::EligibilityChecker)
            .to receive(:new).with(no_args).and_call_original

          finder.execute
        end
      end

      context 'when MembershipEligibilityChecker filters users' do
        let(:resource) { root_group }
        let_it_be(:regular_user) { create(:user) }
        let_it_be(:admin_user) { create(:user, :admin) }

        before do
          filtered_users = User.where(id: [regular_user.id, admin_user.id])
          checker_instance = instance_double(::Members::ServiceAccounts::EligibilityChecker)
          allow(::Members::ServiceAccounts::EligibilityChecker)
            .to receive(:new).with(target_group: root_group).and_return(checker_instance)
          allow(checker_instance).to receive(:filter_users).and_return(filtered_users)
        end

        it 'returns filtered users from MembershipEligibilityChecker' do
          result = finder.execute

          expect(result.map(&:id)).to match_array([regular_user.id, admin_user.id])
        end
      end
    end

    describe 'SSO enforcement' do
      let_it_be(:resource) { project }
      let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: root_group, enforced_sso: true) }

      let_it_be(:user_with_group_saml_identity) do
        create(:user).tap do |user|
          create(:group_saml_identity, saml_provider: saml_provider, user: user)
        end
      end

      let_it_be(:blocked_user_with_group_saml_identity) do
        create(:user, :blocked).tap do |user|
          create(:group_saml_identity, saml_provider: saml_provider, user: user)
        end
      end

      let_it_be(:group_service_account) { create(:service_account, provisioned_by_group: root_group) }
      let_it_be(:blocked_group_service_account) { create(:service_account, :blocked, provisioned_by_group: root_group) }

      before do
        stub_licensed_features(group_saml: true)
      end

      context 'when SSO enforcement is enabled' do
        it 'returns only users with SAML identity and group service accounts' do
          result = finder.execute

          expect(result).to include(user_with_group_saml_identity, group_service_account)
          expect(result).not_to include(blocked_user_with_group_saml_identity, blocked_group_service_account)
        end
      end

      context 'when SSO enforcement is disabled' do
        before do
          saml_provider.update!(enforced_sso: false)
        end

        it 'returns all searchable users' do
          result = finder.execute

          expect(result).to include(user_with_group_saml_identity, group_service_account, current_user)
        end
      end
    end

    describe 'service account invite restrictions' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:instance_sa) { create(:user, :service_account, provisioned_by_group: nil) }
      let_it_be(:root_group_sa) { create(:user, :service_account, provisioned_by_group: root_group) }
      let_it_be(:subgroup_sa) { create(:user, :service_account, provisioned_by_group: subgroup) }
      let_it_be(:other_group_sa) { create(:user, :service_account, provisioned_by_group: other_group) }

      describe 'composite identity restrictions', :saas do
        before do
          stub_saas_features(service_accounts_invite_restrictions: true)
        end

        context 'when inviting to root group' do
          let(:resource) { root_group }

          it 'includes instance-level SA with composite identity' do
            sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)

            expect(finder.execute).to include(sa)
          end

          it 'includes SA from same group with composite identity' do
            sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)

            expect(finder.execute).to include(sa)
          end

          it 'excludes SA from other group with composite identity' do
            sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)

            expect(finder.execute).not_to include(sa)
          end

          it 'includes SA without composite identity from any group' do
            sa = create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: other_group)

            expect(finder.execute).to include(sa)
          end
        end

        context 'when inviting to subgroup' do
          let(:resource) { subgroup }

          it 'includes SAs from ancestor groups with composite identity' do
            root_sa = create(:user, :service_account, composite_identity_enforced: true,
              provisioned_by_group: root_group)
            sub_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)

            result = finder.execute

            expect(result).to include(root_sa, sub_sa)
          end

          it 'excludes SAs from other groups with composite identity' do
            sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)

            expect(finder.execute).not_to include(sa)
          end
        end

        context 'when inviting to project in personal namespace' do
          let_it_be(:personal_project) do
            create(:project, creator: current_user, namespace: create(:namespace, owner: current_user))
          end

          let(:resource) { personal_project }

          it 'excludes composite-ID SAs from any group' do
            sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)

            expect(finder.execute).not_to include(sa)
          end

          it 'includes SAs without composite identity' do
            sa = create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: root_group)

            expect(finder.execute).to include(sa)
          end
        end
      end

      describe 'subgroup hierarchy restrictions' do
        before do
          stub_feature_flags(allow_subgroups_to_create_service_accounts: true)
        end

        context 'when inviting to root group' do
          let(:resource) { root_group }

          it 'excludes SAs provisioned by subgroups' do
            expect(finder.execute).not_to include(subgroup_sa)
          end

          it 'includes instance-level and root group SAs' do
            expect(finder.execute).to include(instance_sa, root_group_sa)
          end
        end

        context 'when inviting to subgroup' do
          let(:resource) { subgroup }

          it 'includes SAs from the subgroup and its ancestors' do
            expect(finder.execute).to include(instance_sa, root_group_sa, subgroup_sa)
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(allow_subgroups_to_create_service_accounts: false)
          end

          let(:resource) { root_group }

          it 'still applies subgroup hierarchy restrictions (FF only controls SA creation, not invite restrictions)' do
            expect(finder.execute).not_to include(subgroup_sa)
          end
        end
      end

      describe 'project-provisioned service account restrictions' do
        let_it_be(:project_in_root) { create(:project, namespace: root_group) }

        let_it_be(:project_sa) do
          create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end
        end

        before do
          stub_feature_flags(allow_projects_to_create_service_accounts: true)
        end

        context 'when inviting to the origin project' do
          let(:resource) { project_in_root }

          it 'includes the project-provisioned SA' do
            expect(finder.execute).to include(project_sa)
          end
        end

        context 'when inviting to a different project' do
          let_it_be(:resource) { create(:project, namespace: root_group) }

          it 'excludes the project-provisioned SA' do
            expect(finder.execute).not_to include(project_sa)
          end
        end

        context 'when inviting to a group (including parent of origin project)' do
          let(:resource) { root_group }

          it 'excludes the project-provisioned SA' do
            expect(finder.execute).not_to include(project_sa)
          end
        end

        context 'when inviting to a subgroup' do
          let(:resource) { subgroup }

          it 'excludes the project-provisioned SA' do
            expect(finder.execute).not_to include(project_sa)
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(allow_projects_to_create_service_accounts: false)
          end

          let(:resource) { root_group }

          it 'still applies project restrictions (FF only controls SA creation, not invite restrictions)' do
            expect(finder.execute).not_to include(project_sa)
          end
        end
      end

      describe 'when only composite identity restriction is disabled' do
        before do
          stub_saas_features(service_accounts_invite_restrictions: false)
        end

        let(:resource) { root_group }

        it 'still applies subgroup and project restrictions (FF only controls SA creation, not invite restrictions)' do
          project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project.id)
          end

          result = finder.execute

          expect(result).to include(instance_sa, root_group_sa, other_group_sa)
          expect(result).not_to include(subgroup_sa, project_sa)
        end
      end
    end
  end
end
