# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::CreateService, feature_category: :user_management do
  shared_examples 'service account creation failure' do
    it 'produces an error', :aggregate_failures do
      expect(result.status).to eq(:error)
      expect(result.message).to eq(
        s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
      )
    end
  end

  shared_examples 'invalid namespace scenarios' do
    context 'when the group is invalid' do
      let(:namespace_id) { non_existing_record_id }

      it_behaves_like 'service account creation failure'
    end

    context 'when the group is subgroup' do
      let(:namespace_id) { subgroup.id }

      it_behaves_like 'service account creation failure'
    end
  end

  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }

  let(:namespace_id) { group.id }

  subject(:service) do
    described_class.new(current_user, { organization_id: organization.id, namespace_id: namespace_id })
  end

  context 'when self-managed' do
    before do
      stub_licensed_features(service_accounts: true)
      allow(License).to receive(:current).and_return(license)
    end

    context 'when current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      context 'when subscription is of starter plan' do
        let(:license) { create(:license, plan: License::STARTER_PLAN) }

        it 'raises error' do
          expect(result.status).to eq(:error)
          expect(result.message).to include('No more seats are available to create Service Account User')
        end
      end

      context 'when subscription is ultimate tier' do
        let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

        it_behaves_like 'service account creation success' do
          let(:username_prefix) { "service_account_group_#{group.id}" }
        end

        it 'sets provisioned by group' do
          expect(result.payload[:user].provisioned_by_group_id).to eq(group.id)
        end

        it_behaves_like 'invalid namespace scenarios'
      end

      context 'when subscription is of premium tier' do
        let(:license) { create(:license, plan: License::PREMIUM_PLAN) }
        let_it_be(:service_account_without_composite) do
          create(:user, :service_account, provisioned_by_group_id: group.id, composite_identity_enforced: false)
        end

        let_it_be(:service_account_without_composite2) do
          create(:user, :service_account, provisioned_by_group_id: group.id, composite_identity_enforced: false)
        end

        let_it_be(:service_account_with_composite) do
          create(:user, :service_account, provisioned_by_group_id: group.id, composite_identity_enforced: true)
        end

        context 'when premium seats are not available' do
          before do
            allow(license).to receive(:seats).and_return(1)
          end

          it 'raises error' do
            expect(result.status).to eq(:error)
            expect(result.message).to include('No more seats are available to create Service Account User')
          end
        end

        context 'when premium seats are available' do
          before do
            allow(license).to receive(:seats).and_return(User.service_accounts_without_composite_identity.count + 2)
          end

          it_behaves_like 'service account creation success' do
            let(:username_prefix) { "service_account_group_#{group.id}" }
          end

          it 'sets provisioned by group' do
            expect(result.payload[:user].provisioned_by_group_id).to eq(group.id)
          end

          it_behaves_like 'invalid namespace scenarios'
        end

        context 'when service accounts with composite_identity_enforced exist' do
          it 'does not count them toward the seat limit' do
            # We have 2 service accounts with composite_identity_enforced: false
            # and 1 service account with composite_identity_enforced: true (AI Agent)
            # If we set seats to 3, we should be able to create 1 more (since only 2 without composite count)
            allow(license).to receive(:seats).and_return(3)

            result = service.execute

            expect(result.status).to eq(:success)
          end
        end
      end
    end

    context 'when current user is not an admin' do
      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      context "when not a group owner" do
        let_it_be(:current_user) { create(:user, maintainer_of: group) }

        it_behaves_like 'service account creation failure'
      end

      context 'when group owner' do
        let_it_be(:current_user) { create(:user, owner_of: group) }

        context 'when application setting is disabled' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
          end

          it_behaves_like 'service account creation failure'

          context 'when gitlab_com_subscriptions saas feature is available' do
            before do
              stub_saas_features(gitlab_com_subscriptions: true)
            end

            it_behaves_like 'service account creation failure'
          end
        end

        context 'when application setting is enabled' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          end

          it_behaves_like 'service account creation success' do
            let(:username_prefix) { "service_account_group_#{group.id}" }
          end

          context 'when gitlab_com_subscriptions saas feature is available', :saas do
            let_it_be(:group) { create(:group_with_plan, owners: current_user) }

            before do
              stub_saas_features(gitlab_com_subscriptions: true)
            end

            it_behaves_like 'service account creation success' do
              let(:username_prefix) { "service_account_group_#{group.id}" }
            end
          end

          # setting is only applicable for top level group
          context 'when the group is subgroup' do
            let(:namespace_id) { subgroup.id }

            it_behaves_like 'service account creation failure'

            context 'when gitlab_com_subscriptions saas feature is available' do
              before do
                stub_saas_features(gitlab_com_subscriptions: true)
              end

              it_behaves_like 'service account creation failure'
            end
          end
        end
      end
    end
  end

  context 'when SaaS', :saas do
    before do
      stub_licensed_features(service_accounts: true)
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    context 'when current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      context 'when subscription is of gold tier' do
        let_it_be(:group_with_gold) { create(:group) }
        let(:namespace_id) { group_with_gold.id }

        before do
          # Reflecting real production data: Gold subscriptions have 0 seats
          create(:gitlab_subscription, :gold, namespace: group_with_gold, seats: 0)
        end

        it_behaves_like 'service account creation success' do
          let(:username_prefix) { "service_account_group_#{group_with_gold.id}" }
        end

        it 'sets provisioned by group' do
          expect(result.payload[:user].provisioned_by_group_id).to eq(group_with_gold.id)
        end

        it_behaves_like 'invalid namespace scenarios'
      end

      context 'when subscription is of ultimate tier' do
        let_it_be(:group_with_ultimate) { create(:group) }
        let(:namespace_id) { group_with_ultimate.id }

        before do
          create(:gitlab_subscription, :ultimate, namespace: group_with_ultimate, seats: 10)
        end

        it_behaves_like 'service account creation success' do
          let(:username_prefix) { "service_account_group_#{group_with_ultimate.id}" }
        end

        it 'sets provisioned by group' do
          expect(result.payload[:user].provisioned_by_group_id).to eq(group_with_ultimate.id)
        end

        it_behaves_like 'invalid namespace scenarios'
      end
    end

    context 'when current user is a group owner' do
      let_it_be(:group_with_trial) { create(:group) }
      let_it_be(:current_user) { create(:user, owner_of: group_with_trial) }
      let(:namespace_id) { group_with_trial.id }

      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      context 'when subscription of type trial' do
        before do
          create(:gitlab_subscription, :active_trial, namespace: group_with_trial, hosted_plan: create(:ultimate_plan))
        end

        context 'when trial service account limit is not reached' do
          before do
            create_list(:user, 5, :service_account, provisioned_by_group_id: group_with_trial.id,
              composite_identity_enforced: false)
            create_list(:user, 5, :service_account, provisioned_by_group_id: group_with_trial.id,
              composite_identity_enforced: true)
          end

          it_behaves_like 'service account creation success' do
            let(:username_prefix) { "service_account_group_#{group_with_trial.id}" }
          end

          it 'sets provisioned by group' do
            expect(result.payload[:user].provisioned_by_group_id).to eq(group_with_trial.id)
          end

          it 'does not count service accounts with composite_identity_enforced toward limit' do
            # We have 5 service accounts without composite and 5 with composite
            # Only the 5 without composite should count toward the limit of 100
            expect(group_with_trial.provisioned_users.service_accounts_without_composite_identity.count).to eq(5)
          end
        end

        context 'when trial service account limit is reached' do
          before do
            stub_const('GitlabSubscription::SERVICE_ACCOUNT_LIMIT_FOR_TRIAL', 3)

            create_list(:user, GitlabSubscription::SERVICE_ACCOUNT_LIMIT_FOR_TRIAL, :service_account,
              provisioned_by_group_id: group_with_trial.id, composite_identity_enforced: false)
            create_list(:user, 5, :service_account,
              provisioned_by_group_id: group_with_trial.id, composite_identity_enforced: true)
          end

          it 'produces an error' do
            expect(result.status).to eq(:error)
            expect(result.message).to include('No more seats are available to create Service Account User')
          end

          it 'does not count service accounts with composite_identity_enforced toward limit' do
            # We have 3 service accounts without composite (at limit) and 5 with composite
            # Only the 3 without composite should count toward the limit
            expect(group_with_trial.provisioned_users.service_accounts_without_composite_identity.count).to eq(3)
          end
        end

        context 'when subscription trial has expired' do
          let_it_be(:group_with_expired_trial) { create(:group, owners: current_user) }
          let(:namespace_id) { group_with_expired_trial.id }

          before do
            create(:gitlab_subscription,
              namespace: group_with_expired_trial,
              hosted_plan: create(:premium_plan),
              trial: true,
              trial_starts_on: 2.weeks.ago,
              trial_ends_on: 1.day.ago,
              seats: 5)

            create_list(:user, 2, :service_account, provisioned_by_group_id: group_with_expired_trial.id,
              composite_identity_enforced: false)
            create_list(:user, 1, :service_account, provisioned_by_group_id: group_with_expired_trial.id,
              composite_identity_enforced: true)
          end

          context 'when regular subscription seats are available' do
            it_behaves_like 'service account creation success' do
              let(:username_prefix) { "service_account_group_#{group_with_expired_trial.id}" }
            end

            it 'does not count service accounts with composite_identity_enforced toward limit' do
              # We have 2 service accounts without composite and 1 with composite
              # Only the 2 without composite should count toward the limit
              expect(
                group_with_expired_trial.provisioned_users.service_accounts_without_composite_identity.count
              ).to eq(2)
            end
          end

          context 'when regular subscription seats are not available' do
            before do
              group_with_expired_trial.gitlab_subscription.update!(seats: 2)
            end

            it 'produces an error' do
              expect(result.status).to eq(:error)
              expect(result.message).to include('No more seats are available to create Service Account User')
            end
          end
        end
      end
    end
  end

  def result
    service.execute
  end
end
