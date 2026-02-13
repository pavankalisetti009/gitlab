# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::BaseCreateService, feature_category: :user_management do
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:group) { create(:group) }

  let(:current_user) { admin }
  let(:params) { { organization_id: organization.id } }

  let(:test_service_class) do
    test_group = group
    Class.new(described_class) do
      define_method(:resource) { test_group }

      def resource_type
        'group'
      end

      def provisioning_params
        { group_id: resource.id, provisioned_by_group_id: resource.id }
      end
    end
  end

  subject(:service) { test_service_class.new(current_user, params) }

  before do
    stub_licensed_features(service_accounts: true)
    allow(License).to receive(:current).and_return(create(:license, plan: License::ULTIMATE_PLAN))
  end

  describe 'abstract method enforcement' do
    let(:base_service) { described_class.new(current_user, params) }

    it 'raises Gitlab::AbstractMethodError for #resource' do
      expect { base_service.execute }.to raise_error(Gitlab::AbstractMethodError)
    end
  end

  describe '#execute', :enable_admin_mode do
    context 'when all conditions are met' do
      it 'creates service account successfully', :aggregate_failures do
        result = service.execute

        expect(result.status).to eq(:success)
        expect(result.payload[:user].user_type).to eq('service_account')
        expect(result.payload[:user].provisioned_by_group_id).to eq(group.id)
      end

      it 'generates username with correct prefix' do
        result = service.execute

        expect(result.payload[:user].username).to start_with("service_account_group_#{group.id}")
      end
    end

    context 'when resource is nil' do
      before do
        allow_next_instance_of(test_service_class) do |svc|
          allow(svc).to receive(:resource).and_return(nil)
        end
      end

      it 'returns error' do
        result = service.execute

        expect(result.status).to eq(:error)
        expect(result.message).to include('does not have permission')
      end
    end

    context 'when user does not have permission' do
      let(:current_user) { create(:user) }

      it 'returns forbidden error', :aggregate_failures do
        result = service.execute

        expect(result.status).to eq(:error)
        expect(result.message).to include('does not have permission')
      end
    end

    context 'with uniquify_provided_username option' do
      let(:username_param) { 'my-username' }
      let(:params) { { organization_id: organization.id, username: username_param } }

      subject(:service) { test_service_class.new(current_user, params, uniquify_provided_username: true) }

      context 'when username is available' do
        it 'uses the provided username' do
          result = service.execute

          expect(result.payload[:user].username).to eq(username_param)
        end
      end

      context 'when username is taken by existing user' do
        before do
          create(:user, username: username_param)
        end

        it 'uniquifies the username', :aggregate_failures do
          result = service.execute
          username = result.payload[:user].username

          expect(username).to start_with(username_param)
          expect(username.length).to eq(username_param.length + 7)
        end
      end

      context 'when username conflicts with namespace path' do
        before do
          create(:group, path: username_param)
        end

        it 'uniquifies the username', :aggregate_failures do
          result = service.execute
          username = result.payload[:user].username

          expect(username).to start_with(username_param)
          expect(username.length).to eq(username_param.length + 7)
        end
      end
    end
  end

  describe 'subscription validation' do
    context 'when on SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when no subscription exists' do
        let_it_be(:group_without_subscription) { create(:group) }

        let(:test_service_class) do
          test_group = group_without_subscription
          Class.new(described_class) do
            define_method(:resource) { test_group }

            def resource_type
              'group'
            end

            def provisioning_params
              { group_id: resource.id, provisioned_by_group_id: resource.id }
            end
          end
        end

        it 'returns error', :enable_admin_mode do
          result = service.execute

          expect(result.status).to eq(:error)
          expect(result.message).to include('No more seats are available')
        end
      end

      context 'when subscription is expired' do
        let_it_be(:group_with_expired) { create(:group) }

        let(:test_service_class) do
          test_group = group_with_expired
          Class.new(described_class) do
            define_method(:resource) { test_group }

            def resource_type
              'group'
            end

            def provisioning_params
              { group_id: resource.id, provisioned_by_group_id: resource.id }
            end
          end
        end

        before do
          create(:gitlab_subscription, :expired, namespace: group_with_expired)
        end

        it 'returns error', :enable_admin_mode do
          result = service.execute

          expect(result.status).to eq(:error)
          expect(result.message).to include('No more seats are available')
        end
      end

      context 'when subscription has no plan_name' do
        let_it_be(:group_without_plan) { create(:group) }

        let(:test_service_class) do
          test_group = group_without_plan
          Class.new(described_class) do
            define_method(:resource) { test_group }

            def resource_type
              'group'
            end

            def provisioning_params
              { group_id: resource.id, provisioned_by_group_id: resource.id }
            end
          end
        end

        before do
          create(:gitlab_subscription, namespace: group_without_plan, hosted_plan: nil)
        end

        it 'returns error', :enable_admin_mode do
          result = service.execute

          expect(result.status).to eq(:error)
          expect(result.message).to include('No more seats are available')
        end
      end

      context 'when subscription is paid and not on trial' do
        let_it_be(:group_with_premium) { create(:group) }

        let(:test_service_class) do
          test_group = group_with_premium
          Class.new(described_class) do
            define_method(:resource) { test_group }

            def resource_type
              'group'
            end

            def provisioning_params
              { group_id: resource.id, provisioned_by_group_id: resource.id }
            end
          end
        end

        before do
          create(:gitlab_subscription, :premium, namespace: group_with_premium)
        end

        it 'creates service account successfully', :enable_admin_mode do
          result = service.execute

          expect(result.status).to eq(:success)
        end
      end

      context 'when on trial' do
        let_it_be(:group_with_trial) { create(:group) }

        let(:test_service_class) do
          test_group = group_with_trial
          Class.new(described_class) do
            define_method(:resource) { test_group }

            def resource_type
              'group'
            end

            def provisioning_params
              { group_id: resource.id, provisioned_by_group_id: resource.id }
            end
          end
        end

        before do
          create(:gitlab_subscription, :active_trial, namespace: group_with_trial, hosted_plan: create(:ultimate_plan))
        end

        context 'when unlimited service accounts feature flag is enabled' do
          it 'creates service account successfully', :enable_admin_mode do
            result = service.execute

            expect(result.status).to eq(:success)
          end
        end

        context 'when unlimited service accounts feature flag is disabled' do
          before do
            stub_feature_flags(allow_unlimited_service_account_for_trials: false)
            stub_const('GitlabSubscription::SERVICE_ACCOUNT_LIMIT_FOR_TRIAL', 2)
          end

          context 'when under the limit' do
            before do
              create(:user, :service_account, provisioned_by_group_id: group_with_trial.id)
            end

            it 'creates service account successfully', :enable_admin_mode do
              result = service.execute

              expect(result.status).to eq(:success)
            end
          end

          context 'when at the limit' do
            before do
              create_list(:user, 2, :service_account, provisioned_by_group_id: group_with_trial.id)
            end

            it 'returns error', :enable_admin_mode do
              result = service.execute

              expect(result.status).to eq(:error)
              expect(result.message).to include('No more seats are available')
            end
          end
        end
      end
    end

    context 'when self-managed' do
      it 'creates service account successfully', :enable_admin_mode do
        result = service.execute

        expect(result.status).to eq(:success)
      end
    end
  end

  describe 'service account counting' do
    let_it_be(:counting_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: counting_group) }
    let_it_be(:project) { create(:project, group: counting_group) }

    let(:test_service_class) do
      test_group = counting_group
      Class.new(described_class) do
        define_method(:resource) { test_group }

        def resource_type
          'group'
        end

        def provisioning_params
          { group_id: resource.id, provisioned_by_group_id: resource.id }
        end
      end
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      create(:gitlab_subscription, :active_trial, namespace: counting_group, hosted_plan: create(:ultimate_plan))
      stub_feature_flags(allow_unlimited_service_account_for_trials: false)
      stub_const('GitlabSubscription::SERVICE_ACCOUNT_LIMIT_FOR_TRIAL', 3)
    end

    context 'when counting hierarchy service accounts', :saas do
      it 'counts both group and project provisioned service accounts', :enable_admin_mode do
        create(:user, :service_account, provisioned_by_group_id: counting_group.id)
        create(:user, :service_account, provisioned_by_project_id: project.id)
        create(:user, :service_account, provisioned_by_group_id: counting_group.id)

        result = service.execute

        expect(result.status).to eq(:error)
        expect(result.message).to include('No more seats are available')
      end

      it 'excludes composite identity service accounts from count', :enable_admin_mode do
        create(:user, :service_account, provisioned_by_group_id: counting_group.id)
        create(:user, :service_account, provisioned_by_group_id: counting_group.id, composite_identity_enforced: true)
        create(:user, :service_account, provisioned_by_project_id: project.id, composite_identity_enforced: true)

        result = service.execute

        expect(result.status).to eq(:success)
      end
    end

    context 'when not counting hierarchy service accounts', :saas do
      before do
        stub_feature_flags(allow_projects_to_create_service_accounts: false)
      end

      it 'counts only group provisioned service accounts', :enable_admin_mode do
        create_list(:user, 2, :service_account, provisioned_by_group_id: counting_group.id)
        create(:user, :service_account, provisioned_by_project_id: project.id)

        result = service.execute

        expect(result.status).to eq(:success)
      end

      it 'includes subgroup service accounts in count', :enable_admin_mode do
        create_list(:user, 2, :service_account, provisioned_by_group_id: counting_group.id)
        create(:user, :service_account, provisioned_by_group_id: subgroup.id)

        result = service.execute

        expect(result.status).to eq(:error)
        expect(result.message).to include('No more seats are available')
      end
    end
  end

  describe '#skip_owner_check?' do
    it 'returns false by default' do
      expect(service.send(:skip_owner_check?)).to be false
    end
  end
end
