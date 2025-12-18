# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::DashboardPolicy, feature_category: :custom_dashboards_foundation do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:member) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:creator) { create(:user) }

  before_all do
    create(:organization_user, :owner, organization: organization, user: owner)
    create(:organization_user, organization: organization, user: member)
    create(:organization_user, organization: organization, user: creator)
    create(:organization_user, organization: organization, user: developer)
    create(:organization_user, organization: organization, user: reporter)
    namespace.add_developer(developer)
    namespace.add_reporter(reporter)
  end

  before do
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(custom_dashboard_storage: true)
  end

  describe 'delegation to organization policy' do
    let_it_be(:dashboard) { create(:dashboard, organization: organization, namespace: nil) }

    subject(:policy) { described_class.new(owner, dashboard) }

    it 'delegates read_custom_dashboard permission to organization' do
      expect(policy.allowed?(:read_custom_dashboard)).to eq(
        Ability.allowed?(owner, :read_custom_dashboard, organization)
      )
    end

    it 'delegates create_custom_dashboard permission to organization' do
      expect(policy.allowed?(:create_custom_dashboard)).to eq(
        Ability.allowed?(owner, :create_custom_dashboard, organization)
      )
    end
  end

  describe 'organization-scoped dashboards' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:org_dashboard) { create(:dashboard, organization: organization, namespace: nil, created_by: creator) }

    where(:user_role, :read, :can_create, :update, :delete) do
      :owner      | true  | true      | true   | true
      :member     | true  | false     | false  | false
      :creator    | true  | false     | false  | false
      :non_member | false | false     | false  | false
    end

    with_them do
      let(:current_user) { public_send(user_role) }

      subject(:policy) { described_class.new(current_user, org_dashboard) }

      it { is_expected.to(read ? be_allowed(:read_custom_dashboard) : be_disallowed(:read_custom_dashboard)) }
      it { is_expected.to(can_create ? be_allowed(:create_custom_dashboard) : be_disallowed(:create_custom_dashboard)) }
      it { is_expected.to(update ? be_allowed(:update_custom_dashboard) : be_disallowed(:update_custom_dashboard)) }
      it { is_expected.to(delete ? be_allowed(:delete_custom_dashboard) : be_disallowed(:delete_custom_dashboard)) }
    end
  end

  describe 'namespace-scoped dashboards' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:ns_dashboard) do
      create(:dashboard, organization: organization, namespace: namespace, created_by: creator)
    end

    where(:user_role, :read, :can_create, :update, :delete) do
      :developer  | true  | true      | true   | true
      :reporter   | true  | false     | false  | false
      :creator    | false | false     | false  | false
      :owner      | false | false     | false  | false
      :non_member | false | false     | false  | false
    end

    with_them do
      let(:current_user) { public_send(user_role) }

      subject(:policy) { described_class.new(current_user, ns_dashboard) }

      it { is_expected.to(read ? be_allowed(:read_custom_dashboard) : be_disallowed(:read_custom_dashboard)) }
      it { is_expected.to(can_create ? be_allowed(:create_custom_dashboard) : be_disallowed(:create_custom_dashboard)) }
      it { is_expected.to(update ? be_allowed(:update_custom_dashboard) : be_disallowed(:update_custom_dashboard)) }
      it { is_expected.to(delete ? be_allowed(:delete_custom_dashboard) : be_disallowed(:delete_custom_dashboard)) }
    end

    context 'when creator has namespace reporter access' do
      let_it_be(:creator_with_access) { create(:user) }
      let_it_be(:ns_dashboard_by_creator) do
        create(:dashboard, organization: organization, namespace: namespace, created_by: creator_with_access)
      end

      before_all do
        create(:organization_user, organization: organization, user: creator_with_access)
        namespace.add_reporter(creator_with_access)
      end

      subject(:policy) { described_class.new(creator_with_access, ns_dashboard_by_creator) }

      it { is_expected.to be_allowed(:read_custom_dashboard) }
      it { is_expected.not_to be_allowed(:create_custom_dashboard) }
      it { is_expected.to be_allowed(:update_custom_dashboard) }
      it { is_expected.to be_allowed(:delete_custom_dashboard) }
    end
  end

  describe 'license and feature flag checks' do
    let_it_be(:dashboard) { create(:dashboard, organization: organization) }

    subject(:policy) { described_class.new(owner, dashboard) }

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it { is_expected.not_to be_allowed(:read_custom_dashboard) }
      it { is_expected.not_to be_allowed(:create_custom_dashboard) }
      it { is_expected.not_to be_allowed(:update_custom_dashboard) }
      it { is_expected.not_to be_allowed(:delete_custom_dashboard) }
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(custom_dashboard_storage: false)
      end

      it { is_expected.not_to be_allowed(:read_custom_dashboard) }
      it { is_expected.not_to be_allowed(:create_custom_dashboard) }
      it { is_expected.not_to be_allowed(:update_custom_dashboard) }
      it { is_expected.not_to be_allowed(:delete_custom_dashboard) }
    end
  end

  describe 'is_dashboard_creator condition coverage' do
    let_it_be(:dashboard) do
      create(
        :dashboard,
        organization: organization,
        namespace: namespace,
        created_by: creator
      )
    end

    before_all do
      namespace.add_reporter(creator)
      namespace.add_reporter(member)
    end

    context 'when user IS the dashboard creator' do
      subject(:policy) { described_class.new(creator, dashboard) }

      it 'evaluates creator condition as true' do
        expect(policy.allowed?(:update_custom_dashboard)).to be(true)
      end
    end

    context 'when user is NOT the dashboard creator' do
      subject(:policy) { described_class.new(member, dashboard) }

      it 'evaluates creator condition as false' do
        expect(policy.allowed?(:update_custom_dashboard)).to be(false)
      end
    end
  end
end
